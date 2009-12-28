/*
 * Copyright (c) 2002 by Atomic Object LLC
 * All rights reserved.
 *
 * VMwareFB+Accel.m -- acceleration methods for VMware display driver
 *
 * Created by Bill Bereza 2001/01/17
 * $Id$
 */

#import "VMwareFB.h"
#import <driverkit/i386/IOPCIDeviceDescription.h>
#import <driverkit/i386/IOPCIDirectDevice.h>

#include <string.h>

/* The 'Accel' category of 'VMwareFB' */
@implementation VMwareFB (Accel)

/*
 * Do accelerated FIFO commands based on parameters.
 * Print out unknown params before passing to super, for debug.
 */
- (IOReturn) setIntValues: (unsigned int *) array
             forParameter: (IOParameterName) parameter
                    count: (unsigned int) count
{
	VMLog ("VMwareFB: setIntValues for param: %s\n", parameter);
	if (!strcmp (parameter, VMWAREUPDATE_PARAM)) {
		[self updateFullScreen];
		return IO_R_SUCCESS;
	} else {
		return [super setIntValues: array
		              forParameter: parameter
		                     count: count];
	}
}


- (IOReturn) getIntValues: (unsigned int *)array
             forParameter: (IOParameterName) parameter
                    count: (unsigned int *)count
{
	VMLog ("VMwareFB: getIntValues for param: %s\n", parameter);
	return [super getIntValues: array
	              forParameter: parameter
	                     count: count];
}


- (IOReturn) getCharValues: (unsigned char *) array
              forParameter: (IOParameterName) parameter
                     count: (unsigned int *)count
{
	VMLog ("VMwareFB: getCharValues for param: %s\n", parameter);
	return [super getCharValues: array
	               forParameter: parameter
	                      count: count];
}


- (IOReturn) setCharValues: (unsigned char *)array
              forParameter: (IOParameterName) parameter
                     count: (unsigned int) count
{
	VMLog ("VMwareFB: setCharValues for param: %s\n", parameter);
	return [super setCharValues: array
	               forParameter: parameter
	                      count: count];
}

@end
