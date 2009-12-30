/*
 * Copyright (c) 2002 by Atomic Object LLC
 * All rights reserved.
 *
 * VMwareFB+Utility.m -- utility methods for VMware display driver
 *
 * Created by Bill Bereza 2001/01/17
 * $Id$
 */

#import "VMwareFB.h"
#import <driverkit/i386/IOPCIDeviceDescription.h>
#import <driverkit/i386/IOPCIDirectDevice.h>

/* The 'Utility' category of 'VMwareFB' */
@implementation VMwareFB (Utility)
/*
 * Use IOLog to print information about this device.
 */
- (void) logInfo
{
	IODisplayInfo *displayInfo = [self displayInfo];		// selected display info

	IOLog ("VMware Display Driver by Atomic Object LLC\n");
	IOLog ("Build Date:    %s\n\n", VM_BUILD_DATE);
	IOLog ("HW Info:\n");
	IOLog ("Registers:     0x%04x (index), 0x%04x (value)\n", indexReg, valueReg);
	IOLog ("Host Caps:     0x%08x\n", vmwareCapability);
	IOLog ("Selected mode: %d (%dx%d, %d bytes/line)\n",
	       selectedMode, displayInfo->width, displayInfo->height, displayInfo->rowBytes);
	IOLog ("FB virt. addr: 0x%08x\n", (unsigned int)displayInfo->frameBuffer);

	// 2002-02-13 no fifo
#ifdef VMWARE_ACCEL
    IOLog ("FIFO addr:     0x%08x\n",  (unsigned int)fifo);
#endif

	IOLog ("Bits/pixel:    ");

	switch (displayInfo->bitsPerPixel) {
		case IO_2BitsPerPixel:
			IOLog ("2");
			break;

		case IO_8BitsPerPixel:
			IOLog ("8");
			break;

		case IO_12BitsPerPixel:
			IOLog ("12");
			break;

		case IO_15BitsPerPixel:
			IOLog ("15");
			break;

		case IO_24BitsPerPixel:
			IOLog ("24");
			break;

		case IO_VGA:
			IOLog ("VGA (Paletted)");
			break;

		default:
			IOLog ("Strange [%d]", displayInfo->bitsPerPixel);
			break;
	}
	IOLog ("\nPixel coding:  %s\n", displayInfo->pixelEncoding);

	return;
}


/*
 * Set the pixel encoding using the given bits per pixel,
 * and color masks.
 * The bits per pixel must be less than or equal to IO_MAX_PIXEL_BITS.
 * The color masks specify where in the pixel the color is placed.
 * Return YES on success or NO on error.
 */
- (BOOL) setPixelEncoding: (IOPixelEncoding)pixelEncoding
             bitsPerPixel: (int)bitsPerPixel
                  redMask: (int)redMask
                greenMask: (int)greenMask
                 blueMask: (int)blueMask
{
	int	loop;

	if (bitsPerPixel <= 0 || bitsPerPixel > IO_MAX_PIXEL_BITS) {
		IOLog ("VMwareFB: bad bits per pixel [%d]\n", bitsPerPixel);
		return NO;
	}

	for (loop = 0; loop < bitsPerPixel; loop++) {
		if ((redMask >> loop) & 1) {		// red bit
			pixelEncoding[bitsPerPixel - 1 - loop] = IO_SampleTypeRed;
		} else if ((greenMask >> loop) & 1) {	// green bit
			pixelEncoding[bitsPerPixel - 1 - loop] = IO_SampleTypeGreen;
		} else if ((blueMask >> loop) & 1) {	// blue bit
			pixelEncoding[bitsPerPixel - 1 - loop] = IO_SampleTypeBlue;
		} else {
			pixelEncoding[bitsPerPixel - 1 - loop] = IO_SampleTypeSkip;
		}
	}

	// end of string
	pixelEncoding[bitsPerPixel] = IO_SampleTypeEnd;
	return YES;
}

@end
