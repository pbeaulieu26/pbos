ASM = nasm

BUILD_DIR = build
SRC_DIR = src

.PHONY: all floppy_image kernel bootloader clean always

# 
# Floppy image
#
floppy_image : $(BUILD_DIR)/floppy.img

# mcopy -i $(BUILD_DIR)/floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
$(BUILD_DIR)/floppy.img : bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "PBOS" $(BUILD_DIR)/floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/floppy.img conv=notrunc
	dd if=$(BUILD_DIR)/kernel.bin of=$(BUILD_DIR)/floppy.img obs=1 seek=512 conv=notrunc

#
# Bootloader
#
bootloader : $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin : always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

#
# Kernel
#
kernel : $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin : always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin

#
# Always
#
always:
	mkdir -p $(BUILD_DIR)

#
# clean
#
clean:
	rm -rf $(BUILD_DIR)