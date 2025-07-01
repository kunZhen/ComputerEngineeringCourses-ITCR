import matplotlib.pyplot as plt
import re
import os

# Function to parse the interconnect log and extract relevant statistics
def parse_interconnect_log(filepath):
    stats = {
        'arbitration': "",
        'total_messages': 0,     # Total number of messages processed
        'message_types': {},     # To store different message types
        'processing_times': {},  # To store processing times (average, total, etc.)
        'queue_stats': {}        # To store queue stats (max size, average size)
    }
    
    # Open the interconnect log file and parse line by line
    with open(filepath, 'r') as file:
        for line in file:
            # Extract message counts based on different types
            if "Arbitration:" in line:
                stats['arbitration'] = line.split("Arbitration:")[1].strip()
            elif "Total Messages:" in line:
                stats['total_messages'] = int(re.search(r'Total Messages:\s+(\d+)', line).group(1))
            elif "READ_MEM:" in line:
                stats['message_types']['READ_MEM'] = int(re.search(r'READ_MEM:\s+(\d+)', line).group(1))
            elif "WRITE_MEM:" in line:
                stats['message_types']['WRITE_MEM'] = int(re.search(r'WRITE_MEM:\s+(\d+)', line).group(1))
            elif "INVALIDATIONS:" in line:
                stats['message_types']['BROADCAST_INVALIDATE'] = int(re.search(r'INVALIDATIONS:\s+(\d+)', line).group(1))
            elif "Average:" in line:
                stats['processing_times']['average'] = float(re.search(r'Average:\s+([\d.]+)', line).group(1))
            elif "Total:" in line:
                stats['processing_times']['total'] = float(re.search(r'Total:\s+([\d.]+)', line).group(1))
            elif "Max Size:" in line:
                stats['queue_stats']['max_size'] = int(re.search(r'Max Size:\s+(\d+)', line).group(1))
            elif "Average Size:" in line:
                stats['queue_stats']['average_size'] = float(re.search(r'Average Size:\s+([\d.]+)', line).group(1))
    
    return stats

# Function to parse PE stats log and extract relevant statistics for each PE
def parse_pe_stats_log(filepath):
    pe_stats = {}
    current_pe = None
    current_section = None

    # Open the PE stats log and parse line by line
    with open(filepath, 'r') as file:
        for line in file:
            # Detect new PE section
            if "PE" in line and "Stats" in line:
                current_pe = int(re.search(r'PE (\d+)', line).group(1))
                pe_stats[current_pe] = {
                    'total_messages': 0,
                    'sent': 0,
                    'received': 0,
                    'discarded': 0,
                    'avg_transfer_time': 0,
                    'min_transfer_time': 0,
                    'max_transfer_time': 0,
                    'avg_msg_size': 0,
                    'total_msg_size': 0,
                    'active_time': 0,
                    'inactive_time': 0,
                    'total_time': 0
                }
                current_section = None

            # Process stats for the current PE
            elif current_pe is not None:
                # Detect which section of stats we're in
                if "Transfer Times" in line:
                    current_section = 'transfer_times'
                elif "Message Sizes" in line:
                    current_section = 'message_sizes'
                elif "Time Analysis" in line:
                    current_section = 'time_analysis'

                # Extract stats from each section
                elif "Total Messages:" in line:
                    pe_stats[current_pe]['total_messages'] = int(re.search(r'Total Messages:\s+(\d+)', line).group(1))
                elif "Sent:" in line:
                    pe_stats[current_pe]['sent'] = int(re.search(r'Sent:\s+(\d+)', line).group(1))
                elif "Received:" in line:
                    pe_stats[current_pe]['received'] = int(re.search(r'Received:\s+(\d+)', line).group(1))
                elif "Discarded:" in line:
                    pe_stats[current_pe]['discarded'] = int(re.search(r'Discarded:\s+(\d+)', line).group(1))

                # Extract averages for transfer times or message sizes
                elif "Average:" in line:
                    value = float(re.search(r'Average:\s+([\d.]+)', line).group(1))
                    if current_section == 'transfer_times':
                        pe_stats[current_pe]['avg_transfer_time'] = value
                    elif current_section == 'message_sizes':
                        pe_stats[current_pe]['avg_msg_size'] = value

                # Extract min and max transfer times
                elif "Min:" in line and current_section == 'transfer_times':
                    pe_stats[current_pe]['min_transfer_time'] = float(re.search(r'Min:\s+([\d.]+)', line).group(1))
                elif "Max:" in line and current_section == 'transfer_times':
                    pe_stats[current_pe]['max_transfer_time'] = float(re.search(r'Max:\s+([\d.]+)', line).group(1))

                # Extract total message size and time analysis
                elif "Total:" in line:
                    value = float(re.search(r'Total:\s+([\d.]+)', line).group(1))
                    if current_section == 'message_sizes':
                        pe_stats[current_pe]['total_msg_size'] = value
                    elif current_section == 'time_analysis':
                        pe_stats[current_pe]['total_time'] = value

                # Extract active and inactive times from time analysis
                elif "Active:" in line and current_section == 'time_analysis':
                    pe_stats[current_pe]['active_time'] = float(re.search(r'Active:\s+([\d.]+)', line).group(1))
                elif "Inactive:" in line and current_section == 'time_analysis':
                    pe_stats[current_pe]['inactive_time'] = float(re.search(r'Inactive:\s+([\d.]+)', line).group(1))

    return pe_stats

# Function to plot interconnect message types
def plot_interconnect_message_types(stats, base_dir):
    plt.figure(figsize=(8, 5))
    labels = list(stats['message_types'].keys())
    values = list(stats['message_types'].values())
    total = sum(values)

    def autopct_format(pct):
        count = int(round(pct * total / 100))
        return f'{pct:.1f}%\n({count})'

    # Create the pie chart
    plt.pie(
        values,
        labels=labels,
        colors=['skyblue', 'lightgreen', 'salmon'],
        autopct=autopct_format,
        startangle=90,
        textprops={'fontsize': 10},
        wedgeprops={'linewidth': 0.5, 'edgecolor': 'white'},
    )
    plt.title(f'Messages processed by the Interconnect\n{stats['arbitration']} Arbitration', pad=60)

    processing_times = (
        f"Processing Times (μs):\n"
        f"Total: {stats['processing_times']['total']}\n"
        f"Avg: {stats['processing_times']['average']:.2f}"
    )
    plt.gcf().text(
        0.05, 0.78,  
        processing_times,
        fontsize=10,
        ha='left',  
        va='center', 
        bbox=dict(
            facecolor='white',
            alpha=0.7,
            boxstyle='round',  
            edgecolor='lightgray'  
        )
    )

    total_messages = (
        f"Total Messages: {stats['total_messages']}"
    )
    plt.gcf().text(
        0.40, 0.72,  
        total_messages,
        fontsize=10,
        ha='left',  
        va='center',  
        bbox=dict(
            facecolor='white',
            alpha=0.7,
            boxstyle='round',  
            edgecolor='lightgray'  
        )
    )

    queue_stats = (
        f"Queue Statistics:\n"
        f"Max Size: {stats['queue_stats']['max_size']}\n"
        f"Avg Size: {stats['queue_stats']['average_size']:.2f}"
    )
    plt.gcf().text(
        0.80, 0.78,  
        queue_stats,
        fontsize=10,
        ha='left', 
        va='center',  
        bbox=dict(
            facecolor='white',
            alpha=0.7,
            boxstyle='round',  
            edgecolor='lightgray' 
        )
    )

    plt.tight_layout()
    if stats['arbitration'] == "QoS":
        plt.savefig(os.path.join(base_dir, 'interconnect_qos_message_types.png'), dpi=300, bbox_inches='tight')
    else:
        plt.savefig(os.path.join(base_dir, 'interconnect_fifo_message_types.png'), dpi=300, bbox_inches='tight')
    plt.show()

# Function to plot PE activity percentage
def plot_pe_activity(pe_stats, arbitration, base_dir):
    plt.figure(figsize=(8, 5))
    pe_ids = sorted(pe_stats.keys())

    # Calculate activity percentage for each PE
    activity_percent = [100 * pe_stats[pe]['active_time'] / pe_stats[pe]['total_time'] if pe_stats[pe]['total_time'] > 0 else 0 for pe in pe_ids]

    # Create a bar chart for PE activity
    bars = plt.bar(pe_ids, activity_percent, color='green')
    plt.title(f'PE Time Active Percentage\n{arbitration} Arbitration')
    plt.xlabel('PE ID')
    plt.ylabel('Time Active (%)')
    plt.ylim(0, 100)
    plt.grid(axis='y')

    # Set x-axis ticks to show every integer value
    plt.xticks(pe_ids)

    # Add labels on top of the bars
    for bar in bars:
        plt.text(bar.get_x() + bar.get_width()/2., bar.get_height(), f'{bar.get_height():.1f}%', ha='center', va='bottom')

    plt.tight_layout()
    if arbitration == "QoS":
        plt.savefig(os.path.join(base_dir, 'pe_qos_activity.png'))
    else:
        plt.savefig(os.path.join(base_dir, 'pe_fifo_activity.png'))
    plt.show()

# Function to plot bandwidth for each PE
def plot_pe_bandwidth(pe_stats, arbitration, base_dir):
    plt.figure(figsize=(8, 5))
    pe_ids = sorted(pe_stats.keys())

    # Calculate bandwidth in Kbps for each PE
    bandwidths_kbps = [
        (pe_stats[pe]['total_msg_size'] * 8 / pe_stats[pe]['total_time']) * (1_000_000 / 1_000) 
        if pe_stats[pe]['total_time'] > 0 
        else 0 
        for pe in pe_ids
    ]

    # Create a bar chart for bandwidth
    bars = plt.bar(pe_ids, bandwidths_kbps, color='mediumslateblue')
    plt.title(f'Bandwidth per PE\n{arbitration} Arbitration')
    plt.xlabel('PE ID')
    plt.ylabel('Bandwidth (Kbps)')
    plt.grid(axis='y')

    # Set x-axis ticks to show every integer value
    plt.xticks(pe_ids)
    
    # Add labels on top of the bars
    for bar in bars:
        plt.text(bar.get_x() + bar.get_width()/2., bar.get_height(), f'{bar.get_height():.1f}', ha='center', va='bottom')

    plt.tight_layout()
    if arbitration == "QoS":
        plt.savefig(os.path.join(base_dir, 'pe_qos_bandwidth.png'))
    else:
        plt.savefig(os.path.join(base_dir, 'pe_fifo_bandwidth.png'))
    plt.show()


# Main script execution
if __name__ == "__main__":
    # Base directory for saving the graphics
    base_dir = os.path.dirname(os.path.abspath(__file__))

    # File paths for the logs
    interconnect_file = os.path.join(base_dir, '..', 'logs', 'interconnect_stats_log.txt')
    pes_file = os.path.join(base_dir, '..', 'logs', 'pes_stats_log.txt')

    # Parse the logs
    interconnect_stats = parse_interconnect_log(interconnect_file)
    pe_stats = parse_pe_stats_log(pes_file)

    plt.ion()  # Turn on interactive mode for live plotting

    # Generate and save the plots
    plot_interconnect_message_types(interconnect_stats, base_dir)
    plot_pe_activity(pe_stats, interconnect_stats['arbitration'], base_dir)
    plot_pe_bandwidth(pe_stats, interconnect_stats['arbitration'], base_dir)

    plt.ioff()  # Turn off interactive mode
    plt.show()  # Display all plots
