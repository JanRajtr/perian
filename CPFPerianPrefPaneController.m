#import "CPFPerianPrefPaneController.h"
#import <Security/Security.h>
#include <sys/stat.h>

#define AC3DynamicRangeKey CFSTR("dynamicRange")
#define AC3StereoOverDolbyKey CFSTR("useStereoOverDolby")

@implementation CPFPerianPrefPaneController

#pragma mark Private Functions

- (void)setButton:(NSButton *)button fromKey:(CFStringRef)key forAppID:(CFStringRef)appID withDefault:(BOOL)defaultValue
{
	CFPropertyListRef value;	
	value = CFPreferencesCopyAppValue(key, appID);
	if(value && CFGetTypeID(value) == CFBooleanGetTypeID())
		[button setState:CFBooleanGetValue(value)];
	else
		[button setState:defaultValue];
	
	if(value)
		CFRelease(value);
}

- (void)setKey:(CFStringRef)key forAppID:(CFStringRef)appID fromButton:(NSButton *)button
{
	if([button state])
		CFPreferencesSetAppValue(key, kCFBooleanTrue, appID);
	else
		CFPreferencesSetAppValue(key, kCFBooleanFalse, appID);
}

- (BOOL)systemInstalled
{
	NSString *myPath = [[self bundle] bundlePath];
	
	if([myPath hasPrefix:NSHomeDirectory()])
		return NO;
	return YES;
}

- (NSString *)quickTimeComponentDir
{
	NSString *basePath = nil;
	
	if(![self systemInstalled])
		basePath = NSHomeDirectory();
	else
		basePath = [NSString stringWithString:@"/"];
	
	return [basePath stringByAppendingPathComponent:@"Library/QuickTime"];
}

- (NSString *)coreAudioComponentDir
{
	NSString *basePath = nil;
	
	if(![self systemInstalled])
		basePath = NSHomeDirectory();
	else
		basePath = [NSString stringWithString:@"/"];
	
	return [basePath stringByAppendingPathComponent:@"Library/Audio/Plug-Ins/Components"];
}

- (NSString *)frameworkComponentDir
{
	NSString *basePath = nil;
	
	if(![self systemInstalled])
		basePath = NSHomeDirectory();
	else
		basePath = [NSString stringWithString:@"/"];
	
	return [basePath stringByAppendingPathComponent:@"Library/Frameworks"];
}

- (InstallStatus)installStatusForComponent:(NSString *)component type:(ComponentType)type withMyVersion:(NSString *)myVersion
{
	NSString *path = nil;
	
	switch(type)
	{
		case ComponentTypeCoreAudio:
			path = [self coreAudioComponentDir];
			break;
		case ComponentTypeQuickTime:
			path = [self quickTimeComponentDir];
			break;
		case ComponentTypeFramework:
			path = [self frameworkComponentDir];
			break;
	}
	path = [path stringByAppendingPathComponent:component];
	
	NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict == nil)
		return InstallStatusNotInstalled;
	
	NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];
	if([currentVersion compare:myVersion] == NSOrderedAscending)
		return InstallStatusOutdated;
	
	return InstallStatusInstalled;
}

#pragma mark Preference Pane Support

- (id)initWithBundle:(NSBundle *)bundle
{
    if ( ( self = [super initWithBundle:bundle] ) != nil ) {
		perianForumURL = [[NSURL alloc] initWithString:@"http://forums.cocoaforge.com/index.php?c=12"];
		perianDonateURL = [[NSURL alloc] initWithString:@"http://perian.org/donate.php"];
		perianWebSiteURL = [[NSURL alloc] initWithString:@"http://perian.org"];
		
		perianAppID = CFSTR("org.perian.perian");
		a52AppID = CFSTR("com.cod3r.a52codec");
    }
    
    return self;
}

- (void)checkForInstallation
{
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	installStatus = [self installStatusForComponent:@"Perian.component" type:ComponentTypeQuickTime withMyVersion:[infoDict objectForKey:BundleVersionKey]];
	if(installStatus == InstallStatusNotInstalled)
	{
		[textField_installStatus setStringValue:NSLocalizedString(@"Perian is not Installed", @"")];
		[button_install setTitle:NSLocalizedString(@"Install Perian", @"")];
	}
	else if(installStatus == InstallStatusOutdated)
	{
		[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but Outdated", @"")];
		[button_install setTitle:NSLocalizedString(@"Update Perian", @"")];
	}
	else
	{
		//Perian is fine, but check components
		NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];
		if(myComponentsInfo != nil)
		{
			NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
			NSDictionary *componentInfo = nil;
			while((componentInfo = [componentEnum nextObject]) != nil)
			{
				InstallStatus tstatus = [self installStatusForComponent:[componentInfo objectForKey:ComponentNameKey] type:[[componentInfo objectForKey:ComponentTypeKey] intValue] withMyVersion:[componentInfo objectForKey:BundleVersionKey]];
				if(tstatus < installStatus)
					installStatus = tstatus;
			}
			switch(installStatus)
			{
				case InstallStatusNotInstalled:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but parts are Not Installed", @"")];
					[button_install setTitle:NSLocalizedString(@"Install Perian", @"")];
					break;
				case InstallStatusOutdated:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed, but parts are Outdated", @"")];
					[button_install setTitle:NSLocalizedString(@"Update Perian", @"")];
					break;
				case InstallStatusInstalled:
					[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed", @"")];
					[button_install setTitle:NSLocalizedString(@"Uninstall Perian", @"")];
					break;
			}
		}
		else
		{
			[textField_installStatus setStringValue:NSLocalizedString(@"Perian is Installed", @"")];
			[button_install setTitle:NSLocalizedString(@"Uninstall Perian", @"")];
		}
		
	}
}

- (void)mainViewDidLoad
{
	/* General */
	[self checkForInstallation];
	
	/* A52 Prefs */
	[self setButton:button_ac3DynamicRange fromKey:AC3DynamicRangeKey forAppID:a52AppID withDefault:NO];
	[self setButton:button_ac3StereoOverDolby fromKey:AC3StereoOverDolbyKey forAppID:a52AppID withDefault:NO];
}

- (void)didUnselect
{
	CFPreferencesAppSynchronize(perianAppID);
	CFPreferencesAppSynchronize(a52AppID);
}

- (void) dealloc {
	[perianForumURL release];
	[perianDonateURL release];
	[perianWebSiteURL release];
	[super dealloc];
}

#pragma mark Install/Uninstall

/* Shamelessly ripped from Sparkle */
- (BOOL)_extractArchivePath:archivePath toDestination:(NSString *)destination
{
	BOOL ret = NO;
	struct stat sb;
	if(stat([destination fileSystemRepresentation], &sb) != 0)
		return FALSE;
	
	char *buf = NULL;
	asprintf(&buf,
			 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\"");
	if(!buf)
		return FALSE;
	
	setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
	setenv("DST_PATH", [destination fileSystemRepresentation], 1);
	
	int status = system(buf);
	if(WIFEXITED(status) && WEXITSTATUS(status) == 0)
		ret = YES;

	free(buf);
	unsetenv("SRC_ARCHIVE");
	unsetenv("DST_PATH");
	return ret;
}

- (BOOL)_authenticatedExtractArchivePath:(NSString *)archivePath toDestination:(NSString *)destination finalPath:(NSString *)finalPath authorization:(AuthorizationRef)auth
{
	BOOL ret = NO, oldExist = NO;
	struct stat sb;
	if(stat([finalPath fileSystemRepresentation], &sb) == 0)
		oldExist = YES;
	
	if(stat([destination fileSystemRepresentation], &sb) != 0)
		return FALSE;
	
	char *buf = NULL;
	if(oldExist)
		asprintf(&buf,
				 "mv -f \"$DST_COMPONENT\" \"$TMP_PATH\" && "
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\" && "
				 "rm -rf \"$TMP_PATH\" && "
				 "chown -R %d:%d \"$DST_COMPONENT\"",
				 sb.st_uid, sb.st_gid);
	else
		asprintf(&buf,
				 "ditto -x -k --rsrc \"$SRC_ARCHIVE\" \"$DST_PATH\" && "
				 "chown -R %d:%d \"$DST_COMPONENT\"",
				 sb.st_uid, sb.st_gid);
	if(!buf)
		return FALSE;
	
	setenv("SRC_ARCHIVE", [archivePath fileSystemRepresentation], 1);
	setenv("DST_COMPONENT", [finalPath fileSystemRepresentation], 1);
	setenv("TMP_PATH", [[finalPath stringByAppendingPathExtension:@"old"] fileSystemRepresentation], 1);
	setenv("DST_PATH", [destination fileSystemRepresentation], 1);
	
	char* arguments[] = { "-c", buf, NULL };
	if(AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
	{
		int status;
		int pid = wait(&status);
		if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
			ret = YES;
	}
	free(buf);
	unsetenv("SRC_ARCHIVE");
	unsetenv("$DST_COMPONENT");
	unsetenv("TMP_PATH");
	unsetenv("DST_PATH");
	return ret;
}

- (BOOL)_authenticatedRemove:(NSString *)componentPath authorization:(AuthorizationRef)auth
{
	BOOL ret = NO;
	struct stat sb;
	if(stat([componentPath fileSystemRepresentation], &sb) != 0)
		return FALSE;
	
	char *buf = NULL;
	asprintf(&buf,
			 "rm -rf \"$COMP_PATH\"");
	if(!buf)
		return FALSE;
	
	setenv("COMP_PATH", [componentPath fileSystemRepresentation], 1);
	
	char* arguments[] = { "-c", buf, NULL };
	if(AuthorizationExecuteWithPrivileges(auth, "/bin/sh", kAuthorizationFlagDefaults, arguments, NULL) == errAuthorizationSuccess)
	{
		int status;
		int pid = wait(&status);
		if(pid != -1 && WIFEXITED(status) && WEXITSTATUS(status) == 0)
			ret = YES;
	}
	free(buf);
	unsetenv("COMP_PATH");
	return ret;
}


- (BOOL)installArchive:(NSString *)archivePath forPiece:(NSString *)component type:(ComponentType)type withMyVersion:(NSString *)myVersion andAuthorization:(AuthorizationRef)auth
{
	NSString *containingDir = nil;
	switch(type)
	{
		case ComponentTypeCoreAudio:
			containingDir = [self coreAudioComponentDir];
			break;
		case ComponentTypeQuickTime:
			containingDir = [self quickTimeComponentDir];
			break;
		case ComponentTypeFramework:
			containingDir = [self frameworkComponentDir];
			break;
	}
	InstallStatus pieceStatus = [self installStatusForComponent:component type:type withMyVersion:myVersion];
	if(auth != nil && pieceStatus != InstallStatusInstalled)
	{
		BOOL result = [self _authenticatedExtractArchivePath:archivePath toDestination:containingDir finalPath:[containingDir stringByAppendingPathComponent:component] authorization:auth];
		if(result == NO)
			return NO;
	}
	else
	{
		//Not authenticated
		if(pieceStatus == InstallStatusOutdated)
		{
			//Remove the old one here
			int tag = 0;
			BOOL result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:containingDir destination:@"" files:[NSArray arrayWithObject:component] tag:&tag];
			if(result == NO)
				return NO;
		}
		if(pieceStatus != InstallStatusInstalled)
		{
			//Decompress and install new one
			BOOL result = [self _extractArchivePath:archivePath toDestination:containingDir];
			if(result == NO)
				return NO;
		}		
	}
	return YES;
}

- (void)install:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];
	NSString *componentPath = [[[self bundle] resourcePath] stringByAppendingPathComponent:@"Components"];
	NSString *coreAudioComponentPath = [componentPath stringByAppendingPathComponent:@"CoreAudio"];
	NSString *quickTimeComponentPath = [componentPath stringByAppendingPathComponent:@"QuickTime"];
	NSString *frameworkComponentPath = [componentPath stringByAppendingPathComponent:@"Frameworks"];
	AuthorizationRef auth = nil;
	
	if([self systemInstalled])
	{
		if(!AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) == errAuthorizationSuccess)
			// Try it anyway, it will likely fail, but who knows what kind of screwed up systems people have
			auth = nil;
	}
	
	[self installArchive:[componentPath stringByAppendingPathComponent:@"Perian.zip"] forPiece:@"Perian.component" type:ComponentTypeQuickTime withMyVersion:[infoDict objectForKey:BundleVersionKey] andAuthorization:auth];
	
	NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
	NSDictionary *myComponent = nil;
	while((myComponent = [componentEnum nextObject]) != nil)
	{
		NSString *archivePath = nil;
		ComponentType type = [[myComponent objectForKey:ComponentTypeKey] intValue];
		switch(type)
		{
			case ComponentTypeCoreAudio:
				archivePath = [coreAudioComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
			case ComponentTypeQuickTime:
				archivePath = [quickTimeComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
			case ComponentTypeFramework:
				archivePath = [frameworkComponentPath stringByAppendingPathComponent:[myComponent objectForKey:ComponentArchiveNameKey]];
				break;
		}
		[self installArchive:archivePath forPiece:[myComponent objectForKey:ComponentNameKey] type:type withMyVersion:[myComponent objectForKey:BundleVersionKey] andAuthorization:auth];
	}
	if(auth != nil)
		AuthorizationFree(auth, 0);
	[self performSelectorOnMainThread:@selector(installComplete:) withObject:nil waitUntilDone:NO];
	[pool release];
}

- (void)uninstall:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *infoDict = [[self bundle] infoDictionary];
	NSDictionary *myComponentsInfo = [infoDict objectForKey:ComponentInfoDictionaryKey];
	AuthorizationRef auth = nil;
	
	if([self systemInstalled])
	{
		if(!AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &auth) == errAuthorizationSuccess)
			// Try it anyway, it will likely fail, but who knows what kind of screwed up systems people have
			auth = nil;
	}
	
	int tag = 0;
	BOOL result = NO;
	if(auth != nil)
		[self _authenticatedRemove:[[self quickTimeComponentDir] stringByAppendingPathComponent:@"Perian.component"] authorization:auth];
	else
		result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[self quickTimeComponentDir] destination:@"" files:[NSArray arrayWithObject:@"Perian.component"] tag:&tag];
	
	NSEnumerator *componentEnum = [myComponentsInfo objectEnumerator];
	NSDictionary *myComponent = nil;
	while((myComponent = [componentEnum nextObject]) != nil)
	{
		ComponentType type = [[myComponent objectForKey:ComponentTypeKey] intValue];
		NSString *directory = nil;
		switch(type)
		{
			case ComponentTypeCoreAudio:
				directory = [self coreAudioComponentDir];
				break;
			case ComponentTypeQuickTime:
				directory = [self quickTimeComponentDir];
				break;
			case ComponentTypeFramework:
				directory = [self frameworkComponentDir];
				break;
		}
		if(auth != nil)
			[self _authenticatedRemove:[directory stringByAppendingPathComponent:[myComponent objectForKey:ComponentNameKey]] authorization:auth];
		else
			result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:directory destination:@"" files:[NSArray arrayWithObject:[myComponent objectForKey:ComponentNameKey]] tag:&tag];
	}
	if(auth != nil)
		AuthorizationFree(auth, 0);
	
	[self performSelectorOnMainThread:@selector(installComplete:) withObject:nil waitUntilDone:NO];
	[pool release];
}

- (IBAction)installUninstall:(id)sender
{
	[progress_install startAnimation:sender];
	if(installStatus == InstallStatusInstalled)
		[NSThread detachNewThreadSelector:@selector(uninstall:) toTarget:self withObject:nil];
	else
		[NSThread detachNewThreadSelector:@selector(install:) toTarget:self withObject:nil];
}

- (void)installComplete:(id)sender
{
	[progress_install stopAnimation:sender];
	[self checkForInstallation];
}

#pragma mark Check Updates
- (IBAction)updateCheck:(id)sender 
{
} 

- (IBAction)setAutoUpdateCheck:(id)sender 
{
} 


#pragma mark AC3 
- (IBAction)setAC3DynamicRange:(id)sender 
{
	[self setKey:AC3DynamicRangeKey forAppID:a52AppID fromButton:button_ac3DynamicRange];
} 

- (IBAction)setAC3StereoOverDolby:(id)sender 
{
	[self setKey:AC3StereoOverDolbyKey forAppID:a52AppID fromButton:button_ac3StereoOverDolby];
} 

#pragma mark About 
- (IBAction)launchWebsite:(id)sender 
{
	[[NSWorkspace sharedWorkspace] openURL:perianWebSiteURL];
} 

- (IBAction)launchDonate:(id)sender 
{
	
	[[NSWorkspace sharedWorkspace] openURL:perianDonateURL];
} 

- (IBAction)launchForum:(id)sender 
{
	
	[[NSWorkspace sharedWorkspace] openURL:perianForumURL];
	
}

@end
