# Multi-Processor Interconnect Simulation System

## Project Overview
This C++ simulation models an interconnect fabric for a multi-processor system with:

- Shared memory communication
- Multiple Processing Elements (PEs) with private caches
- Configurable arbitration schemes (FIFO or QoS-based)
- Thread-safe message passing

The system demonstrates how processors communicate through an interconnect to access shared memory while maintaining cache coherence.

## Key Features
- **Configurable Architecture**
  - 2 to 8 Processing Elements (PEs)
  - FIFO or QoS-based arbitration
  - 4KB shared memory (32-bit word aligned)
  
- **Supported Operations**
  - Memory read/write operations
  - Cache invalidation broadcasts
  - Acknowledgment messaging

## Build the Project
### 1. Prerequisites
- C++20 compatible compiler (g++ 13+ recommended)
- Make 4.0+
- Linux/Unix environment

### 2. Compilation
```bash
cd src        # Where the Makefile is
make clean    # Clean previous builds
make          # Compile the simulator
```

## Running the Simulation
### Command-Line Options

| Option       | Description                     | Values       | Default |
|--------------|---------------------------------|--------------|---------|
| `-n`, `--num-pes` | Number of Processing Elements | 2-16          | 8       |
| `-s`, `--scheme`   | Arbitration scheme           | `fifo` or `qos` | `fifo`  |
| `-t`, `--stepping`   | Enable stepping mode           | - | disable  |
| `-h`, `--help`     | Show help message            | -            | -       |


### Common Usage Examples

#### 1. **Default configuration** (4 PEs, FIFO arbitration):
```bash
./simulator
```

#### 2. **Custom number of PEs** (6 PEs, FIFO arbitration):
```bash
./simulator -n 6
```

#### 3. **QoS arbitration scheme** (4 PEs):
```bash
./simulator -s qos
```

#### 4. **Full custom configuration** (8 PEs, QoS arbitration):
```bash
./simulator -n 8 -s qos
```

#### 5. **Full custom configuration with stepping mode** (6 PEs, FIFO arbitration, Enable stepping):
```bash
./simulator -n 6 -s fifo -t
```

#### 6. **Show help message**:
```bash
./simulator --help
```

### Expected Output
The simulator will:

1. Display initialization messages
2. Process all PE instructions
3. Generate files:
   - `interconnect_log.txt`: Detailed message log and final stats of the interconnect
   - `pes_stats_log.txt` Logs final stats for each PE
   - `cache_pe_x.txt`: Final cache state of each PE
   - `data.txt`: Final shared memory state
4. Display system performance statistics upon completion

Example output:
```bash
pending...
```

### Custom Workloads
To create custom workloads:

1. Edit instruction files in `resources/pe_instructions/`:

```bash
READ_MEM <addr>, <size>
WRITE_MEM <addr>, <start_cache_line>, <num_of_cache_lines>
BROADCAST_INVALIDATE <cache_line>
```