/*
 * Copyright (c) 2002 by Atomic Object LLC
 * All rights reserved.
 *
 * VMwareFB.m -- driver for VMware display driver
 *
 * Created by Bill Bereza 2001/01/17
 * $Id: VMwareFB.m,v 1.2 2002/02/14 22:37:38 bereza Exp $
 */

#import "VMwareFB.h"
#include <stdio.h>

#import <driverkit/i386/IOPCIDeviceDescription.h>
#import <driverkit/i386/IOPCIDirectDevice.h>

/*
 * The frameBuffer field is initialized to 0 since it's determined at
 * runtime. The parameters field is left at 0.
 *
 * This is the table of all _possible_ modes this driver supports.
 * Based on the capabilities returned from the device, a specific
 * mode will be selected.
 *
 * Depth will always be ignored, and automatically set to whatever
 * the VMware device reports. All the listed modes below are for
 * 32-bit depth, while should let selectMode:count:valid: pick
 * the right mode based on the resolution selected by the user.
 */
#define RGB32 "--------RRRRRRRRGGGGGGGGBBBBBBBB"
#define MKMODE(x,y) x, y, x, x*4, 60, 0, IO_24BitsPerPixel, IO_RGBColorSpace, RGB32, 0, 0

static const IODisplayInfo modeTable[] = {
	{		// 4:3 modes
		MKMODE (640,480)	/* 640 x 480, RGB:888/32 */
	}, {
		MKMODE (800,600)	/* 800 x 600, RGB:888/32 */
	}, {
		MKMODE (1024,768)	/* 1024 x 768, RGB:888/32 */
	}, {
		MKMODE (1120,832)	/* 1120 x 832, RGB:888/32 */
	}, {
		MKMODE (1152,864)	/* 1152 x 864, RGB:888/32 */
	}, {
		MKMODE (1280,960)	/* 1280 x 960, RGB:888/32 */
	}, {
		MKMODE (1400,1050)	/* 1400 x 1050, RGB:888/32 */
	}, {
		MKMODE (1600,1200)	/* 1600 x 1200, RGB:888/32 */
	}, {
		MKMODE (1920,1440)	/* 1920 x 1440, RGB:888/32 */
	}, {
		MKMODE (2048,1536)	/* 2048 x 1536, RGB:888/32 */
	}, {	// 16:9 modes
		MKMODE (856,480)	/* 856 x 480, RGB:888/32 */
	}, {
		MKMODE (1280,720)	/* 1280 x 720, RGB:888/32 */
	}, {
		MKMODE (1360,768)	/* 1360 x 768, RGB:888/32 */
	}, {
		MKMODE (1366,768)	/* 1366 x 768, RGB:888/32 */
	}, {
		MKMODE (1368,768)	/* 1368 x 768, RGB:888/32 */
	}, {
		MKMODE (1920,1080)	/* 1920 x 1080, RGB:888/32 */
	}, {	// 16:10 modes
		MKMODE (1280,800)	/* 1280 x 800, RGB:888/32 */
	}, {
		MKMODE (1440,900)	/* 1440 x 900, RGB:888/32 */
	}, {
		MKMODE (1680,1050)	/* 1680 x 1050, RGB:888/32 */
	}, {
		MKMODE (1920,1200)	/* 1920 x 1200, RGB:888/32 */
	}, {	// Weird modes
		MKMODE (800,480)	/* 800 x 480, RGB:888/32 */
	}, {
		MKMODE (1024,600)	/* 1024 x 600, RGB:888/32 */
	}, {
		MKMODE (1280,768)	/* 1280 x 768, RGB:888/32 */
	}, {
		MKMODE (1280,1024)	/* 1280 x 1024, RGB:888/32 */
	}
};

#define modeTableCount (sizeof(modeTable) / sizeof(IODisplayInfo))

#define defaultMode 0;

@implementation VMwareFB

/*
 * Probe for existence of the VMware device.
 * (Legacy FB memory range 0x7EFC0000 - 7FFC0000)
 *
 * This method performs the following steps:
 *
 * 1. Get PCI configuration information for the device. Use
 *    getPCIConfig to get the base address.
 *
 * 2. Use the PCI chiptype to decide if the device is a 0710 legacy
 *    chipset to get the index and value registers. Store index and value
 *    registers.  (SVGA_INDEX_PORT, SVGA_VALUE_PORT)
 *
 * 3. Get the VMware ID using getVMwareSVGAID(). If the id is
 *    SVGA_ID_INVALID or SVGA_ID_0, return NO.  (SVGA_REG_ID)
 *
 * 4. Read the frame buffer start and size the registers,
 *    SVGA_REG_FB_START, SVGA_REG_FB_SIZE.	Set the framebuffer memory
 *    range on the IODeviceDesciption with setMemoryRangeList:num: to set
 *    the 0th memory range.  (SVGA_REG_FB_START, SVGA_REG_FB_SIZE)
 *
 * 5. Read the fifo memory start and size the registers,
 *    SVGA_REG_MEM_START, SVGA_REG_MEM_SIZE.  Set the framebuffer memory
 *    range on the IODeviceDesciption with setMemoryRangeList:num: to set
 *    the 1th memory range.  (SVGA_REG_MEM_START, SVGA_REG_MEM_SIZE)
 *
 * 6. alloc an instance and call initFromDeviceDescription:
 *
 * 7. Return YES if initFromDeviceDescription: is successful return
 *    YES, otherwise return NO.
 */
+ (BOOL)probe: deviceDescription
{
	uint16      indexRegister, valueRegister;   /* index and value registers */
	uint32      ident;                          /* SVGA ID of vmware device */
	CARD32      physicalMemoryBase;             /* frame buffer start */
	CARD32      physicalMemorySize;             /* frame buffer size */

	// 2002-02-13 removed
#ifdef VMWARE_ACCEL
	CARD32      fifoBase;                        /* FIFO start */
	CARD32      fifoSize;                        /* FIFO size */
#endif

	int         i;                               // scratch var
	const char  *name = [self name];

	int         numRanges;                       /* number of memory ranges */
	IORange     *oldRange, newRange[3];
	/*
	 * Memory ranges. Should always be 3.
	 * This will be checked.
	 */
	VMwareFB    *newDriver;	// instance of VMwareFB driver

	if ([self getIndexRegister: &indexRegister
	             valueRegister: &valueRegister
	     withDeviceDescription: deviceDescription] != IO_R_SUCCESS) {
		IOLog ("%s: Can't get registers!\n", name);
		return NO;
	}

	IOLog ("%s: Registers at (0x%04x, 0x%04x)\n", name, indexRegister, valueRegister);

	// Get the ID of the version of the VMware device
	ident = [self getVMwareSVGAIDAtIndexRegister: indexRegister valueRegister: valueRegister];

	// don't support version 0 or INVALID
	if (ident == SVGA_ID_0 || ident == SVGA_ID_INVALID) {
		IOLog ("%s: No supported VMware SVGA found (read ID 0x%08x).\n", name, ident);
		return NO;
	}

	// Get the start and size of the frame buffer in physical memory
	physicalMemoryBase = vmwareReadReg (indexRegister, valueRegister, SVGA_REG_FB_START);
	physicalMemorySize = vmwareReadReg (indexRegister, valueRegister, SVGA_REG_FB_SIZE);

	// 2002-02-13 not using fifo
#ifdef VMWARE_ACCEL
	// Get the start and size of the command FIFO in physical memory
	fifoBase = vmwareReadReg (indexRegister, valueRegister, SVGA_REG_MEM_START);
	fifoSize = vmwareReadReg (indexRegister, valueRegister, SVGA_REG_MEM_SIZE);

	VMLog ("%s: Command FIFO at 0x%08x\n", name, fifoBase);
#endif

	VMLog ("%s: Framebuffer at 0x%08x-0x%08x (%d kilobytes)\n",
	       name,
	       physicalMemoryBase,
	       physicalMemoryBase + physicalMemorySize - 1,
	       physicalMemorySize / 1024);

	// get the existing array of memory ranges
	oldRange = [deviceDescription memoryRangeList];
	numRanges = [deviceDescription numMemoryRanges];
	if (numRanges != 3) {
		IOLog ("%s: Incorrect number of address ranges (%d, need 3)\n", name, numRanges);
		return NO;
	}

	/* replace the address */
	for (i = 0; i < numRanges; i++) {
		newRange[i] = oldRange[i];
	}

	// frame buffer
	newRange[0].start = physicalMemoryBase;
	newRange[0].size = physicalMemorySize;

	// 2002-02-13 removed fifo uses
#ifdef VMWARE_ACCEL
	// command fifo
	newRange[1].start = fifoBase;
	newRange[1].size = fifoSize;
#endif

	if ([deviceDescription setMemoryRangeList: newRange num: 3]) {	/* can't set to new memory range */
		IOLog ("%s: Can't set memory range, using default.\n", name);
		for (i = 0; i < numRanges; i++) {
			newRange[i] = oldRange[i];
		}

		physicalMemoryBase = newRange[0].start;
		physicalMemorySize = newRange[0].size;

#ifdef VMWARE_ACCEL
		fifoBase = newRange[1].start;
		fifoSize = newRange[1].size;
#endif

		if ([deviceDescription setMemoryRangeList: newRange num: 3]) {
			/* can't set to old range-->major problem! */
			IOLog("%s: Can't set to default range either!\n", name);
			return NO;
		}
	}

	// 2002-02-14: Maybe we should just return [super probe] here?
	if (!(newDriver = [[self alloc] initFromDeviceDescription: deviceDescription])) {
		IOLog ("VMwareFB probe: problem initializing instance.\n");
		return NO;
	}

	[newDriver setDeviceKind: "Linear Framebuffer"];
	[newDriver registerDevice];

	IOLog("VMwareFB: display initialized and ready to go.\n");
	return YES;
}

/*
 * Initialize the the device driver, and Driver instance.
 *
 * 0. Call [super init...]
 * 
 * 1. Map the frame buffer and and command FIFO into memory.
 *	  (SVGA_REG_FB_START, SVGA_REG_FB_SIZE, SVGA_REG_MEM_START,
 *	   SVGA_REG_MEM_SIZE)
 * 
 * 2. Get the device capabilities and frame buffer dimensions.
 *	  Set boolean capability i-vars to values.
 *	  (SVGA_REG_CAPABILITIES, SVGA_REG_MAX_WIDTH, SVGA_REG_MAX_HEIGHT,
 *	   SVGA_REG_HOST_BITS_PER_PIXEL -or- SVGA_REG_BITS_PER_PIXEL)
 *	  (If SVGA_CAP_8BIT_EMULATIONS is not set, then it is possible that
 *	   SVGA_REG_HOST_BITS_PER_PIXEL does not exist and
 *	   SVGA_REG_BITS_PER_PIXEL should be read instead.)
 *
 * 3. Report the Guest Operating System. (SVGA_REG_GUEST_ID)
 *
 * 4. Call selectMode:count:valid: to select the display mode.
 *
 * 5. Get displayInfo and set it up using selected mode and
 * framebuffer address. Using returned capabilities. (See IODisplay
 * displayInfo method docs). Do not actually enable SVGA.
 * That happens when enterLinearMode is called.
 *
 * 6. Set the mode.
 *	  Set SVGA_REG_WIDTH, SVGA_REG_HEIGHT, SVGA_REG_BITS_PER_PIXEL
 *	  Read SVGA_REG_FB_OFFSET
 *	  (SVGA_REG_FB_OFFSET is the offset from SVGA_REG_FB_START of the
 *	   visible portion of the frame buffer)
 *	  Read SVGA_REG_BYTES_PER_LINE, SVGA_REG_DEPTH, SVGA_REG_PSEUDOCOLOR,
 *	  SVGA_REG_RED_MASK, SVGA_REG_GREEN_MASK, SVGA_REG_BLUE_MASK
 */
- initFromDeviceDescription: deviceDescription
{
	IODisplayInfo *displayInfo;		// selected display info
	const IORange *range;		// framebuffer and fifo memory range
	BOOL validModes[modeTableCount];	// flags for checking valid modes
	int loop;				// loop variable
	const char *accelString;
	IOConfigTable *configuration;	// config table for this driver instance

	// VMware register values
	int maxWidth;			// maximum width as reported by device
	int maxHeight;			// maximum height as reported by device
	int bitsPerPixel = 32;
	int depth;
	CARD32 redMask;
	CARD32 greenMask;
	CARD32 blueMask;
	int fbOffset;
	int bytesPerLine;
	// vmwareCapability is an int i-var

	IOLog("VMwareFB: initFromDeviceDescription.\n");

	if (![super initFromDeviceDescription: deviceDescription]) {
		return [super free];
	}

	fifo = NULL;

	/*
	 * Get the index and value registers into our i-vars.
	 */
	if ([isa getIndexRegister: &indexReg valueRegister: &valueReg
		withDeviceDescription: deviceDescription] != IO_R_SUCCESS)
	{
		IOLog ("VMwareFB: problem getting index and value registers.\n");
		return [super free];
	}

	/*
	 * Read the capabilities to determine maximum width and height.
	 * We will use this information to eliminate some modes.
	 */
	maxWidth = [self readRegister: SVGA_REG_MAX_WIDTH ];
	maxHeight = [self readRegister: SVGA_REG_MAX_HEIGHT ];
	vmwareCapability = [self readRegister: SVGA_REG_CAPABILITIES ];

	VMLog ("VMwareFB: capabilities: maxWidth=%d, maxHeight=%d, flags=%x\n",
	       maxWidth, maxHeight, vmwareCapability);

	/*
	 * special handling needed for bits per pixel.
	 * In any case, it always ends up being the host
	 * machine's bpp.
	 */
	if (vmwareCapability & SVGA_CAP_8BIT_EMULATION) {
		VMLog ("VMwareFB: 8-bit emulation supported: Setting guest BPP to match host\n");

		bitsPerPixel = [self readRegister: SVGA_REG_HOST_BITS_PER_PIXEL];
		switch (bitsPerPixel) {
			case 8:
			case 16:
			case 32:
				bitsPerPixel = [self readRegister: SVGA_REG_BITS_PER_PIXEL];
				break;
			default:
				// OpenStep only supports 8/16/32bpp. since this system can do 8-bit, then change to 8
				IOLog ("VMwareFB: Host bpp %d unsupported, switching to 8-bit emu\n", bitsPerPixel);
				bitsPerPixel = 8;
		}
	}
	VMLog ("VMwareFB: First bits/pixel attempt: %d\n", bitsPerPixel);

	/* report the guest OS */
	[self writeRegister: SVGA_REG_GUEST_ID value: GUEST_OS_OTHER];

	/*
	 * Get the acceleration flag from the config table, and set the
	 * acceleration i-var to one of our acceleration values.
	 */
	configuration = [deviceDescription configTable];
	accelString = [configuration valueForStringKey: VMACCELERATION_KEY];

	acceleration = NO_ACCELERATION;
	// 2002-02-13 removed acceleration
#ifdef VMWARE_ACCEL
	if (accelString) {
		if (!strcmp (VMACCELERATION_NONE, accelString)) {		// no acceleration
			acceleration = NO_ACCELERATION;
		} else if (!strcmp(VMACCELERATION_DEFAULT, accelString)) {	// normal FIFO command update acceleration
			acceleration = DEFAULT_ACCELERATION;
		} else if (!strcmp(VMACCELERATION_CURSOR, accelString)) {	// use cursor acceleration if supported
			if (vmwareCapability & SVGA_CAP_CURSOR) {
				acceleration = CURSOR_ACCELERATION;
			}
		}
	} else {
		acceleration = DEFAULT_ACCELERATION;
	}
#endif

	/* Go through display array, checking which are within max width x height. */
	for (loop = 0; loop < modeTableCount; loop++) {
		if ((modeTable[loop].width > maxWidth) || ( modeTable[loop].height > maxHeight )) {
			validModes[loop] = NO;
		} else {
			validModes[loop] = YES;
		}
	}

	/* selectedMode is a driver-defined instance variable */
	selectedMode = [self selectMode: modeTable
	                          count: modeTableCount
	                          valid: validModes];

	if (selectedMode < 0) {
		IOLog ("%s: Sorry, can't use requested display mode\n", [self name]);
		selectedMode = defaultMode;
	}

	/* get our display info */
	displayInfo = [self displayInfo];
	*displayInfo = modeTable[selectedMode];

	/*
	 * Set the width and height registers from the selected
	 * mode. This will give us framebuffer offset and
	 * bytes per line, and other value, with which we can
	 * change the displayInfo struct.
	 */
	[self writeRegister: SVGA_REG_ENABLE value: 0];	// in-case
	[self writeRegister: SVGA_REG_WIDTH value: displayInfo->width];
	[self writeRegister: SVGA_REG_HEIGHT value: displayInfo->height];

	if ((fbOffset = [self readRegister: SVGA_REG_FB_OFFSET]) > 0) {
		IOLog ("VMwareFB: FB_OFFSET > 0. Not sure what to do. Ignoring it.\n");
	}

	bytesPerLine = [self readRegister: SVGA_REG_BYTES_PER_LINE];
	VMLog ("VMwareFB: Bytes/line: %d\n", bytesPerLine);

	if ([self readRegister: SVGA_REG_PSEUDOCOLOR] == 1) {
		// FIXME: Supporting color mapped mode should be pretty simple.
		// FIXME: It should just be a matter of implementing the transfer
		// FIXME: table stuff.
		// FIXME: Implement this feature some day.
		// Bill Bereza 2002-02-13
		IOLog ("VMwareFB: Colormapped mode not supported! Suggest you change host display mode.\n");
		return [super free];
	}

	/* Re-read bitsPerPixel. The README says to. */
	bitsPerPixel = [self readRegister: SVGA_REG_BITS_PER_PIXEL ];
	redMask = [self readRegister: SVGA_REG_RED_MASK];
	greenMask = [self readRegister: SVGA_REG_GREEN_MASK];
	blueMask = [self readRegister: SVGA_REG_BLUE_MASK];
	depth = [self readRegister: SVGA_REG_DEPTH];

	VMLog ("VMwareFB: Color depth: %d (%d bits/pixel)\n", depth, bitsPerPixel);
	VMLog ("VMwareFB: Color masks: (0x%x, 0x%x, 0x%x)\n", redMask, greenMask, blueMask);

	switch (bitsPerPixel) {
		case 8:
		case 16:
		case 32:
			break;
		default:
			// OpenStep only supports 8, 16 or 32bpp
			IOLog ("VMwareFB: Unsupported bits-per-pixel '%d'.\n", bitsPerPixel);
			return [super free];
	}

	/*
	 * In certain cases, the Windows host appears to
	 * report 16 bpp and 16 depth but 555 weight.  Just
	 * silently convert it to depth of 15.
	 */
	if (depth == 16 && bitsPerPixel == 16 && vmwareCalculateWeight(greenMask) == 5) {
		depth = 15;
	}

	/*
	 * There is no 32 bit depth, apparently it can get
	 * reported this way sometimes on the Windows host.
	 */
	if (depth == 32 && bitsPerPixel == 32) {
		depth = 24;
	}

	/* modify display info using bytesPerLine, depth, and color masks. */

	/* bytesPerLine should be the same as IODisplayInfo rowBytes */
	displayInfo->rowBytes = bytesPerLine;

	/*
	 * Find the right IOBitsPerPixel value from depth.
	 * What the VMware device calls depth, NextStep calls IOBitsPerPixel.
	 */
	switch (depth) {
		case 8:
			displayInfo->bitsPerPixel = IO_8BitsPerPixel;
			break;

		case 12:
			displayInfo->bitsPerPixel = IO_12BitsPerPixel;
			break;

		case 16:
			// probably a 565 color weight
			IOLog ("VMwareFB: Warning: 16 bit depth; suggest switching to 15- or 24-bit mode.\n");

			if (redMask == 0xf800 && greenMask == 0x7e0 && blueMask == 0x1f) {	// yup
				IOLog ("VMwareFB: Hacking around 565 color weight.");
				greenMask = 0x7c0;	// ignore LSB
			}
			// no break; we will use 15 bpp code

		case 15:
			displayInfo->bitsPerPixel = IO_15BitsPerPixel;
			break;

		case 24:
			displayInfo->bitsPerPixel = IO_24BitsPerPixel;
			break;

		default:
			IOLog ("VMwareFB: Error: Unsupported bit depth %d; suggest changing host display mode.\n", depth);
			return [super free];
			break;
	}

	/*
	 * Use bits per-pixel and color masks to generate a pixel
	 * encoding string.
	 */
	[self setPixelEncoding: displayInfo->pixelEncoding
	          bitsPerPixel: bitsPerPixel
	               redMask: redMask
	             greenMask: greenMask
	              blueMask: blueMask];

	VMLog ("VMwareFB: pixel layout [%s]\n", displayInfo->pixelEncoding);

	/* Get memory ranges from device description */
	range = [deviceDescription memoryRangeList];

	VMLog ("VMwareFB: framebuffer range: 0x%08x-0x%08x\n",
	       range[FB_MEMRANGE].start,
	       range[FB_MEMRANGE].start + range[FB_MEMRANGE].size - 1);

	VMLog ("VMwareFB: framebuffer size: 0x%08x\n", range[FB_MEMRANGE].size);

	/* map frame buffer. */
#if 1
	if ([self mapMemoryRange: FB_MEMRANGE to: (vm_address_t *)&(displayInfo->frameBuffer)
	               findSpace: YES
	                   cache: IO_DISPLAY_CACHE_WRITETHROUGH] != IO_R_SUCCESS)
	{
		IOLog ("VMwareFB: problem mapping framebuffer\n");
		return [super free];
	}
#else
	// 2002-02-14: old way of mapping frame buffer
	displayInfo->frameBuffer = (void *)	[self mapFrameBufferAtPhysicalAddress: range[FB_MEMRANGE].start
	                                                                   length: range[FB_MEMRANGE].size];
#endif

	if (!(displayInfo->frameBuffer)) {
		IOLog ("VMwareFB: couldn't map frame buffer memory!\n");
		return [super free];
	}

	// 2002-02-13 Removing all use of FIFO memory
#ifdef VMWARE_ACCEL
	if (acceleration != NO_ACCELERATION) {	/* map command FIFO */
		if ([self mapMemoryRange: FIFO_MEMRANGE
		                      to: (vm_address_t *)&fifo
		               findSpace: YES
		                   cache: IO_CacheOff] != IO_R_SUCCESS)
		{
			IOLog ("VMwareFB: problem mapping command FIFO\n");
			return [super free];
		}
	} else {
		fifo = NULL;
	}
#endif

	IOLog ("VMwareFB: initialized.\n");
	[self logInfo];

	return self;
}

/*
 * Configure display to enter advanced framebuffer mode.
 *
 * 1. Enable SVGA.
 *    Set SVGA_REG_ENABLE to 1
 *    (Set to 0 to disable (to enable VGA))
 *
 * 2. Initialize the command FIFO. (See README)
 *
 * 3. Set SVGA_REG_CONFIG_DONE to 1 (Set to 0 to stop the device reading FIFO)
 */
- (void)enterLinearMode
{
	IOLog ("VMwareFB: enterLinearMode\n");

	[self writeRegister: SVGA_REG_ENABLE value: 1];

	// only turn on if acceleration != NO_ACCELERATION
	if (acceleration == NO_ACCELERATION) {
		VMLog ("VMwareFB: Acceleration disabled\n");
		return;
	}

	VMLog ("VMwareFB: Enabling acceleration with command fifo\n");
	fifoLength = [self readRegister: SVGA_REG_MEM_SIZE] & ~3;
	fifo[SVGA_FIFO_MIN] = 4 * sizeof (CARD32);
	fifo[SVGA_FIFO_MAX] = fifoLength;
	fifo[SVGA_FIFO_NEXT_CMD] = 4 * sizeof (CARD32);
	fifo[SVGA_FIFO_STOP] = 4 * sizeof (CARD32);
	[self writeRegister: SVGA_REG_CONFIG_DONE value: 1];
}


/*
 * Set display back to VGA mode.
 *
 * 1. Turn off FIFO. (SVGA_REG_CONFIG_DONE <- 0).
 *
 * 2. Display SVGA (SVGA_REG_ENABLE <- 0)
 */
- (void)revertToVGAMode
{
	IOLog ("VMwareFB: revertToVGAMode.\n");
	if (acceleration != NO_ACCELERATION) {
		[self writeRegister: SVGA_REG_CONFIG_DONE value: 0];
	}
	[self writeRegister: SVGA_REG_ENABLE value: 0];
	[super revertToVGAMode];
}


/*
 * Unmap the fifo
 */
/* 2002-02-13 May be a problem */
#ifdef VMWARE_ACCEL
- free
{
	if (fifo) {
		[self unmapMemoryRange: FIFO_MEMRANGE from: (vm_address_t)fifo];
	}

	return [super free];
}
#endif

/* disabled, to be removed when updating fully implemented */
#ifdef VMWARE_ACCEL
- (port_t) devicePort
{
	VMLog ("VMwareFB: devicePort\n");
	return [super devicePort];
}

- hideCursor: (int)token
{
	VMLog ("VMwareFB: hideCursor\n");
	return [super hideCursor: token];
}

- moveCursor: (Point *)cursorLoc
       frame: (int)frame
       token: (int)token
{
	[self updateFullScreen];
	return [super moveCursor: cursorLoc
	                   frame: frame
	                   token: token];
}

- setBrightness: (int)level
          token: (int)token
{
	VMLog ("VMwareFB: setBrightness\n");
	return [super setBrightness: level
	                      token: token];
}

- showCursor: (Point *)cursorLocation
       frame: (int)frame
       token: (int)token
{
	VMLog ("VMwareFB: showCursor\n");
	return [super showCursor: cursorLocation
	                   frame: frame
	                   token: token];
}
#endif

@end
