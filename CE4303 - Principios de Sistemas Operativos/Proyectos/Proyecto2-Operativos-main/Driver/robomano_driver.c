/*  robomano_driver.c
 *  Driver de carácter que recibe bytes por /dev/robomano y los re-envía
 *  al Arduino por /dev/ttyUSB0
 *
 *  - Kernel >= 5.10 (usa kernel_write, sin set_fs / get_fs)
 *  - Compilar como módulo fuera del árbol (out-of-tree)
 */
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/device.h>
#include <linux/file.h>
#include <linux/err.h>
#include <linux/version.h>

#define DEVICE_NAME  "robomano"
#define CLASS_NAME   "robomano_class"
#define SERIAL_PORT  "/dev/ttyACM0"

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Henry & equipo");
MODULE_DESCRIPTION("Driver para mano robótica vía Arduino");
MODULE_VERSION("1.1");

static int            major;
static struct class  *robomano_class  = NULL;
static struct device *robomano_device = NULL;

/*------------------------------------------------------------*/
/* write: lo único que necesitas hoy                           */
/*------------------------------------------------------------*/
static ssize_t robomano_write(struct file *fp,
                              const char __user *ubuf,
                              size_t len,
                              loff_t *off)
{
    char         kbuf[128];
    struct file *serial_filp;
    loff_t       pos   = 0;
    ssize_t      nbytes;

    /* –– copiar desde user space –– */
    if (len >= sizeof(kbuf))
        len = sizeof(kbuf) - 1;

    if (copy_from_user(kbuf, ubuf, len))
        return -EFAULT;

    kbuf[len] = '\0';
    pr_info("robomano: recibido \"%s\"\n", kbuf);

    /* –– abrir /dev/ttyUSB0 solo para esta escritura –– */
    serial_filp = filp_open(SERIAL_PORT, O_WRONLY | O_NOCTTY, 0);
    if (IS_ERR(serial_filp)) {
        pr_err("robomano: no pude abrir %s\n", SERIAL_PORT);
        return PTR_ERR(serial_filp);
    }

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
    nbytes = kernel_write(serial_filp, kbuf, len, &pos);
#else
    /*  Para kernels <5.10 (no es tu caso, pero queda documentado) */
    nbytes = vfs_write(serial_filp, kbuf, len, &pos);
#endif

    filp_close(serial_filp, NULL);

    return (nbytes < 0) ? nbytes : len;   /* devolver lo escrito */
}

/*------------------------------------------------------------*/
static struct file_operations fops = {
    .owner = THIS_MODULE,
    .write = robomano_write,
};

/*------------------------------------------------------------*/
static int __init robomano_init(void)
{
    /* 1. registrar major dinámico */
    major = register_chrdev(0, DEVICE_NAME, &fops);
    if (major < 0) {
        pr_alert("robomano: no pude registrar major\n");
        return major;
    }

    /* 2. crear clase y /dev/robomano */
    robomano_class = class_create(CLASS_NAME);
	
    if (IS_ERR(robomano_class)) {
        unregister_chrdev(major, DEVICE_NAME);
        pr_alert("robomano: no pude crear la clase\n");
        return PTR_ERR(robomano_class);
    }

    robomano_device = device_create(robomano_class, NULL,
                                    MKDEV(major,0), NULL, DEVICE_NAME);
    if (IS_ERR(robomano_device)) {
        class_destroy(robomano_class);
        unregister_chrdev(major, DEVICE_NAME);
        pr_alert("robomano: no pude crear el device\n");
        return PTR_ERR(robomano_device);
    }

    pr_info("robomano: listo – /dev/%s\n", DEVICE_NAME);
    return 0;
}

/*------------------------------------------------------------*/
static void __exit robomano_exit(void)
{
    device_destroy(robomano_class, MKDEV(major,0));
    class_unregister(robomano_class);
    class_destroy(robomano_class);
    unregister_chrdev(major, DEVICE_NAME);
    pr_info("robomano: descargado\n");
}

module_init(robomano_init);
module_exit(robomano_exit);
