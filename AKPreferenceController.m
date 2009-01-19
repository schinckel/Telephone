//
//  AKPreferenceController.m
//  Telephone
//
//  Copyright (c) 2008-2009 Alexei Kuznetsov. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY ALEXEI KUZNETSOV "AS IS" AND ANY EXPRESS
//  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
//  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "AKKeychain.h"
#import "AKPreferenceController.h"
#import "AKTelephone.h"
#import "AKTelephoneAccount.h"
#import "AppController.h"
#import "NSStringAdditions.h"
#import "NSWindowAdditions.h"


@interface AKPreferenceController()

- (BOOL)checkForNetworkSettingsChanges:(id)sender;
- (void)networkSettingsChangeAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end

NSString * const AKAccounts = @"Accounts";
NSString * const AKSTUNServerHost = @"STUNServerHost";
NSString * const AKSTUNServerPort = @"STUNServerPort";
NSString * const AKSTUNDomain = @"STUNDomain";
NSString * const AKLogFileName = @"LogFileName";
NSString * const AKLogLevel = @"LogLevel";
NSString * const AKConsoleLogLevel = @"ConsoleLogLevel";
NSString * const AKVoiceActivityDetection = @"VoiceActivityDetection";
NSString * const AKTransportPort = @"TransportPort";
NSString * const AKSoundInput = @"SoundInput";
NSString * const AKSoundOutput = @"SoundOutput";
NSString * const AKRingingSound = @"RingingSound";
NSString * const AKFormatTelephoneNumbers = @"FormatTelephoneNumbers";
NSString * const AKTelephoneNumberFormatterSplitsLastFourDigits = @"TelephoneNumberFormatterSplitsLastFourDigits";
NSString * const AKOutboundProxyHost = @"OutboundProxyHost";
NSString * const AKOutboundProxyPort = @"OutboundProxyPort";

NSString * const AKFullName = @"FullName";
NSString * const AKSIPAddress = @"SIPAddress";
NSString * const AKRegistrar = @"Registrar";
NSString * const AKRealm = @"Realm";
NSString * const AKUsername = @"Username";
NSString * const AKPassword = @"Password";
NSString * const AKAccountIndex = @"AccountIndex";
NSString * const AKAccountEnabled = @"AccountEnabled";

NSString * const AKPreferenceControllerDidAddAccountNotification = @"AKPreferenceControllerDidAddAccount";
NSString * const AKPreferenceControllerDidRemoveAccountNotification = @"AKPreferenceControllerDidRemoveAccount";
NSString * const AKPreferenceControllerDidChangeAccountEnabledNotification = @"AKPreferenceControllerDidChangeAccountEnabled";
NSString * const AKPreferenceControllerDidChangeNetworkSettingsNotification = @"AKPreferenceControllerDidChangeNetworkSettings";

@implementation AKPreferenceController

@dynamic delegate;
@synthesize addAccountWindow;
@synthesize addAccountWindowDefaultButton;
@synthesize addAccountWindowOtherButton;

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)aDelegate
{
	if (delegate == aDelegate)
		return;
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	if (delegate != nil)
		[notificationCenter removeObserver:delegate name:nil object:self];
	
	if (aDelegate != nil) {
		if ([aDelegate respondsToSelector:@selector(preferenceControllerDidAddAccount:)])
			[notificationCenter addObserver:aDelegate
								   selector:@selector(preferenceControllerDidAddAccount:)
									   name:AKPreferenceControllerDidAddAccountNotification
									 object:self];

		if ([aDelegate respondsToSelector:@selector(preferenceControllerDidRemoveAccount:)])
			[notificationCenter addObserver:aDelegate
								   selector:@selector(preferenceControllerDidRemoveAccount:)
									   name:AKPreferenceControllerDidRemoveAccountNotification
									 object:self];
		
		if ([aDelegate respondsToSelector:@selector(preferenceControllerDidChangeAccountEnabled:)])
			[notificationCenter addObserver:aDelegate
								   selector:@selector(preferenceControllerDidChangeAccountEnabled:)
									   name:AKPreferenceControllerDidChangeAccountEnabledNotification
									 object:self];
		
		if ([aDelegate respondsToSelector:@selector(preferenceControllerDidChangeNetworkSettings:)])
			[notificationCenter addObserver:aDelegate
								   selector:@selector(preferenceControllerDidChangeNetworkSettings:)
									   name:AKPreferenceControllerDidChangeNetworkSettingsNotification
									 object:self];
	}
	
	delegate = aDelegate;
}

- (id)init
{
	self = [super initWithWindowNibName:@"Preferences"];
	
	// Subscribe on mouse-down event of the ringing sound selection.
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(popUpButtonWillPopUpNotification:)
												 name:NSPopUpButtonWillPopUpNotification
											   object:ringingSoundPopUp];
	
	return self;
}

- (void)dealloc
{
	[self setDelegate:nil];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (void)windowDidLoad
{
	[self updateAvailableSounds];
	
	[toolbar setSelectedItemIdentifier:[generalToolbarItem itemIdentifier]];
	[[self window] resizeAndSwapToContentView:generalView];
	[[self window] setTitle:NSLocalizedString(@"General", @"General preferences window title.")];
	
	[self updateAudioDevices];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[STUNServerHost setStringValue:[defaults stringForKey:AKSTUNServerHost]];
	if ([[defaults objectForKey:AKSTUNServerPort] integerValue] > 0)
		[STUNServerPort setIntegerValue:[[defaults objectForKey:AKSTUNServerPort] integerValue]];
	[outboundProxyHost setStringValue:[defaults stringForKey:AKOutboundProxyHost]];
	if ([[defaults objectForKey:AKOutboundProxyPort] integerValue] > 0)
		[outboundProxyPort setIntegerValue:[[defaults objectForKey:AKOutboundProxyPort] integerValue]];
		
	NSInteger row = [accountsTable selectedRow];
	if (row == -1)
		return;
	
	[self populateFieldsForAccountAtIndex:row];
}

- (IBAction)changeView:(id)sender
{
	// If the user switches from Network to some other view, check for network settings changes.
	if ([[[self window] contentView] isEqual:networkView] && [sender tag] != AKNetworkPreferencesTag) {
		BOOL networkSettingsChanged = [self checkForNetworkSettingsChanges:sender];
		if (networkSettingsChanged)
			return;
	}
	
	NSView *view;
	NSString *title;
	NSView *firstResponderView;
	
	switch ([sender tag]) {
		case AKGeneralPreferencesTag:
			view = generalView;
			title = NSLocalizedString(@"General", @"General preferences window title.");
			firstResponderView = nil;
			break;
		case AKAccountsPreferencesTag:
			view = accountsView;
			title = NSLocalizedString(@"Accounts", @"Accounts preferences window title.");
			firstResponderView = accountsTable;
			break;
		case AKSoundPreferencesTag:
			view = soundView;
			title = NSLocalizedString(@"Sound", @"Sound preferences window title.");
			firstResponderView = nil;
			break;
		case AKNetworkPreferencesTag:
			view = networkView;
			title = NSLocalizedString(@"Network", @"Network preferences window title.");
			firstResponderView = STUNServerHost;
			break;
		default:
			view = nil;
			title = NSLocalizedString(@"Telephone Preferences", @"Preferences default window title.");
			firstResponderView = nil;
			break;
	}
	
	[[self window] resizeAndSwapToContentView:view animate:YES];
	[[self window] setTitle:title];
	if ([firstResponderView acceptsFirstResponder])
		[[self window] makeFirstResponder:firstResponderView];
}

- (IBAction)showAddAccountSheet:(id)sender
{
	if (addAccountWindow == nil)
		[NSBundle loadNibNamed:@"AddAccount" owner:self];
	
	[setupFullName setStringValue:@""];
	[setupSIPAddress setStringValue:@""];
	[setupRegistrar setStringValue:@""];
	[setupUsername setStringValue:@""];
	[setupPassword setStringValue:@""];
	[addAccountWindow makeFirstResponder:setupFullName];
	
	[NSApp beginSheet:addAccountWindow
	   modalForWindow:[accountsView window]
		modalDelegate:nil
	   didEndSelector:NULL
		  contextInfo:NULL];
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window]];
	[[sender window] orderOut:sender];
}

- (IBAction)addAccount:(id)sender
{
	if ([[setupFullName stringValue] isEqual:@""] ||
		[[setupSIPAddress stringValue] isEqual:@""] ||
		[[setupRegistrar stringValue] isEqual:@""] ||
		[[setupUsername stringValue] isEqual:@""])
	{
		return;
	}
	
	NSMutableDictionary *accountDict = [NSMutableDictionary dictionary];
	[accountDict setObject:[NSNumber numberWithBool:YES] forKey:AKAccountEnabled];
	[accountDict setObject:[setupFullName stringValue] forKey:AKFullName];
	[accountDict setObject:[setupSIPAddress stringValue] forKey:AKSIPAddress];
	[accountDict setObject:[setupRegistrar stringValue] forKey:AKRegistrar];
	[accountDict setObject:@"*" forKey:AKRealm];
	[accountDict setObject:[setupUsername stringValue] forKey:AKUsername];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *savedAccounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:AKAccounts]];
	[savedAccounts addObject:accountDict];
	[defaults setObject:savedAccounts forKey:AKAccounts];
	[defaults synchronize];
	
	// Inform accounts table about update
	[accountsTable reloadData];
	
	BOOL success;
	success = [AKKeychain addItemWithServiceName:[NSString stringWithFormat:@"SIP: %@", [setupRegistrar stringValue]]
									 accountName:[setupUsername stringValue]
										password:[setupPassword stringValue]];
	
	[self closeSheet:sender];
	
	if (success) {
		// Post notification with account just added
		[[NSNotificationCenter defaultCenter] postNotificationName:AKPreferenceControllerDidAddAccountNotification
															object:self
														  userInfo:accountDict];
	}
	
	// Set the selection to the new account
	NSUInteger index = [[defaults arrayForKey:AKAccounts] count] - 1;
	if (index != 0) {
		[accountsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index]
				   byExtendingSelection:NO];
	}
}

- (IBAction)showRemoveAccountSheet:(id)sender
{
	NSInteger index = [accountsTable selectedRow];
	if (index == -1) {
		NSBeep();
		return;
	}
	
	NSTableColumn *theColumn = [[[NSTableColumn alloc] initWithIdentifier:@"SIPAddress"] autorelease];
	NSString *selectedAccount = [[accountsTable dataSource] tableView:accountsTable
											objectValueForTableColumn:theColumn row:index];
	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete button.")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button.")];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete \\U201C%@\\U201D?",
																	   @"Account removal confirmation."),
						   selectedAccount]];
	[alert setInformativeText:[NSString stringWithFormat:
							   NSLocalizedString(@"This will delete your currently set up account \\U201C%@\\U201D.",
												 @"Account removal confirmation informative text."),
							   selectedAccount]];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[accountsTable window]
					  modalDelegate:self
					 didEndSelector:@selector(removeAccountAlertDidEnd:returnCode:contextInfo:)
						contextInfo:NULL];
}

- (void)removeAccountAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
		[self removeAccountAtIndex:[accountsTable selectedRow]];
}

- (void)removeAccountAtIndex:(NSInteger)index
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *savedAccounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:AKAccounts]];
	[savedAccounts removeObjectAtIndex:index];
	[defaults setObject:savedAccounts forKey:AKAccounts];
	[defaults synchronize];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AKPreferenceControllerDidRemoveAccountNotification
														object:self
													  userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:index]
																						   forKey:AKAccountIndex]];
	[accountsTable reloadData];
	
	// Select none, last or previous account.
	if ([savedAccounts count] == 0) {
		return;
	} else if (index >= ([savedAccounts count] - 1)) {
		[accountsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:([savedAccounts count] - 1)] byExtendingSelection:NO];
		[self populateFieldsForAccountAtIndex:([savedAccounts count] - 1)];
	} else {
		[accountsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[self populateFieldsForAccountAtIndex:index];
	}
}

- (void)populateFieldsForAccountAtIndex:(NSInteger)index
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSArray *savedAccounts = [defaults arrayForKey:AKAccounts];
	
	if (index >= 0) {
		NSDictionary *accountDict = [savedAccounts objectAtIndex:index];
		
		[accountEnabledCheckBox setEnabled:YES];
		
		if ([[accountDict objectForKey:AKAccountEnabled] boolValue]) {
			[accountEnabledCheckBox setState:NSOnState];
			[fullName setEnabled:NO];
			[SIPAddress setEnabled:NO];
			[registrar setEnabled:NO];
			[username setEnabled:NO];
			[password setEnabled:NO];
		} else {
			[accountEnabledCheckBox setState:NSOffState];
			[fullName setEnabled:YES];
			[SIPAddress setEnabled:YES];
			[registrar setEnabled:YES];
			[username setEnabled:YES];
			[password setEnabled:YES];
		}
		
		[fullName setStringValue:[accountDict objectForKey:AKFullName]];
		[SIPAddress setStringValue:[accountDict objectForKey:AKSIPAddress]];
		[registrar setStringValue:[accountDict objectForKey:AKRegistrar]];
		[username setStringValue:[accountDict objectForKey:AKUsername]];

		[password setStringValue:[AKKeychain passwordForServiceName:[NSString stringWithFormat:@"SIP: %@",
																	 [accountDict objectForKey:AKRegistrar]]
														accountName:[accountDict objectForKey:AKUsername]]];
	} else {
		[accountEnabledCheckBox setState:NSOffState];
		[fullName setStringValue:@""];
		[SIPAddress setStringValue:@""];
		[registrar setStringValue:@""];
		[username setStringValue:@""];
		[password setStringValue:@""];
		
		[accountEnabledCheckBox setEnabled:NO];
		[fullName setEnabled:NO];
		[SIPAddress setEnabled:NO];
		[registrar setEnabled:NO];
		[username setEnabled:NO];
		[password setEnabled:NO];
	}
}

- (IBAction)changeAccountEnabled:(id)sender
{
	if ([accountsTable selectedRow] == -1)
		return;	
	
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];

	NSInteger index = [accountsTable selectedRow];
	[userInfo setObject:[NSNumber numberWithInteger:index] forKey:AKAccountIndex];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray *savedAccounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:AKAccounts]];
	NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:[savedAccounts objectAtIndex:index]];
	
	BOOL isChecked = ([accountEnabledCheckBox state] == NSOnState) ? YES : NO;
	[accountDict setObject:[NSNumber numberWithBool:isChecked] forKey:AKAccountEnabled];
	
	if (isChecked) {
		// User enabled the account.
		// Account fields could be edited, save them.
		[accountDict setObject:[fullName stringValue] forKey:AKFullName];
		[accountDict setObject:[SIPAddress stringValue] forKey:AKSIPAddress];
		[accountDict setObject:[registrar stringValue] forKey:AKRegistrar];
		[accountDict setObject:[username stringValue] forKey:AKUsername];
		[AKKeychain addItemWithServiceName:[NSString stringWithFormat:@"SIP: %@", [registrar stringValue]]
							   accountName:[username stringValue]
								  password:[password stringValue]];
		
		// Disable account fields.
		[fullName setEnabled:NO];
		[SIPAddress setEnabled:NO];
		[registrar setEnabled:NO];
		[username setEnabled:NO];
		[password setEnabled:NO];
		
		// Mark accounts table as needing redisplay.
		[accountsTable reloadData];
		
	} else {
		// User disabled the account, enable account fields.
		[fullName setEnabled:YES];
		[SIPAddress setEnabled:YES];
		[registrar setEnabled:YES];
		[username setEnabled:YES];
		[password setEnabled:YES];
	}
	
	[savedAccounts replaceObjectAtIndex:index withObject:accountDict];
	
	// Save to defaults
	[defaults setObject:savedAccounts forKey:AKAccounts];
	[defaults synchronize];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:AKPreferenceControllerDidChangeAccountEnabledNotification
														object:self
													  userInfo:userInfo];
}

- (IBAction)changeSoundIO:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:[soundInputPopUp titleOfSelectedItem] forKey:AKSoundInput];
	[defaults setObject:[soundOutputPopUp titleOfSelectedItem] forKey:AKSoundOutput];
	
	[[NSApp delegate] selectSoundIO];
}

- (void)updateAudioDevices
{
	// Populate sound IO pop-up buttons
	NSArray *audioDevices = [[NSApp delegate] audioDevices];
	NSMenu *soundInputMenu = [[NSMenu alloc] init];
	NSMenu *soundOutputMenu = [[NSMenu alloc] init];
	NSInteger i;
	for (i = 0; i < [audioDevices count]; ++i) {
		NSDictionary *deviceDict = [audioDevices objectAtIndex:i];
		
		NSMenuItem *aMenuItem = [[NSMenuItem alloc] init];
		[aMenuItem setTitle:[deviceDict objectForKey:AKAudioDeviceName]];
		[aMenuItem setTag:i];
		
		if ([[deviceDict objectForKey:AKAudioDeviceInputsCount] integerValue] > 0)
			[soundInputMenu addItem:[[aMenuItem copy] autorelease]];
		
		if ([[deviceDict objectForKey:AKAudioDeviceOutputsCount] integerValue] > 0)
			[soundOutputMenu addItem:[[aMenuItem copy] autorelease]];
		
		[aMenuItem release];
	}
	
	[soundInputPopUp setMenu:soundInputMenu];
	[soundOutputPopUp setMenu:soundOutputMenu];
	
	[soundInputMenu release];
	[soundOutputMenu release];
	
	// Select saved sound devices
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *lastSoundInput = [defaults stringForKey:AKSoundInput];
	if (lastSoundInput != nil && [soundInputPopUp itemWithTitle:lastSoundInput] != nil)
		[soundInputPopUp selectItemWithTitle:lastSoundInput];
	
	NSString *lastSoundOutput = [defaults stringForKey:AKSoundOutput];
	if (lastSoundOutput != nil && [soundOutputPopUp itemWithTitle:lastSoundOutput] != nil)
		[soundOutputPopUp selectItemWithTitle:lastSoundOutput];
}

- (void)updateAvailableSounds
{
	NSMenu *soundsMenu = [[NSMenu alloc] init];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSSet *allowedSoundFileExtensions = [NSSet setWithObjects:@"aiff", @"aif", @"aifc",
										 @"mp3", @"wav", @"sd2", @"au", @"snd", @"m4a", @"m4p", nil];
	
	// Get sounds from ~/Library/Sounds.
	NSArray *userSoundFiles = [fileManager contentsOfDirectoryAtPath:[@"~/Library/Sounds" stringByExpandingTildeInPath] error:NULL];
	for (NSString *aFile in userSoundFiles) {
		if (![allowedSoundFileExtensions containsObject:[aFile pathExtension]])
			continue;
		NSString *aSound = [aFile stringByDeletingPathExtension];
		if ([soundsMenu itemWithTitle:aSound] == nil) {
			NSMenuItem *aMenuItem = [[NSMenuItem alloc] init];
			[aMenuItem setTitle:aSound];
			[soundsMenu addItem:aMenuItem];
			[aMenuItem release];
		}
	}
	
	// Get sounds from /Library/Sounds.
	NSArray *sharedLocalSoundFiles = [fileManager contentsOfDirectoryAtPath:@"/Library/Sounds" error:NULL];
	if ([sharedLocalSoundFiles count] > 0)
		[soundsMenu addItem:[NSMenuItem separatorItem]];
	for (NSString *aFile in sharedLocalSoundFiles) {
		if (![allowedSoundFileExtensions containsObject:[aFile pathExtension]])
			continue;
		NSString *aSound = [aFile stringByDeletingPathExtension];
		if ([soundsMenu itemWithTitle:aSound] == nil) {
			NSMenuItem *aMenuItem = [[NSMenuItem alloc] init];
			[aMenuItem setTitle:aSound];
			[soundsMenu addItem:aMenuItem];
			[aMenuItem release];
		}
	}
	
	// Get sounds from /Network/Library/Sounds.
	NSArray *networkSoundFiles = [fileManager contentsOfDirectoryAtPath:@"/Network/Library/Sounds" error:NULL];
	if ([networkSoundFiles count] > 0)
		[soundsMenu addItem:[NSMenuItem separatorItem]];
	for (NSString *aFile in networkSoundFiles) {
		if (![allowedSoundFileExtensions containsObject:[aFile pathExtension]])
			continue;
		NSString *aSound = [aFile stringByDeletingPathExtension];
		if ([soundsMenu itemWithTitle:aSound] == nil) {
			NSMenuItem *aMenuItem = [[NSMenuItem alloc] init];
			[aMenuItem setTitle:aSound];
			[soundsMenu addItem:aMenuItem];
			[aMenuItem release];
		}
	}
	
	// Get sounds from /System/Library/Sounds.
	NSArray *systemSoundFiles = [fileManager contentsOfDirectoryAtPath:@"/System/Library/Sounds" error:NULL];
	if ([systemSoundFiles count] > 0)
		[soundsMenu addItem:[NSMenuItem separatorItem]];
	for (NSString *aFile in systemSoundFiles) {
		if (![allowedSoundFileExtensions containsObject:[aFile pathExtension]])
			continue;
		NSString *aSound = [aFile stringByDeletingPathExtension];
		if ([soundsMenu itemWithTitle:aSound] == nil) {
			NSMenuItem *aMenuItem = [[NSMenuItem alloc] init];
			[aMenuItem setTitle:aSound];
			[soundsMenu addItem:aMenuItem];
			[aMenuItem release];
		}
	}
	
	[ringingSoundPopUp setMenu:soundsMenu];
	NSString *savedSound = [[NSUserDefaults standardUserDefaults] stringForKey:AKRingingSound];
	if ([soundsMenu itemWithTitle:savedSound] != nil)
		[ringingSoundPopUp selectItemWithTitle:savedSound];
	
	[soundsMenu release];
}

- (IBAction)changeIncomingCallSound:(id)sender
{
	// Stop currently playing sound.
	[[[NSApp delegate] incomingCallSound] stop];
	
	NSString *soundName = [sender title];
	[[NSUserDefaults standardUserDefaults] setObject:soundName forKey:AKRingingSound];
	[[NSApp delegate] setIncomingCallSound:[NSSound soundNamed:soundName]];
	
	// Play selected sound once.
	[[[NSApp delegate] incomingCallSound] play];
}

// Check if network settings were changed, show an alert sheet to save, cancel or don't save.
// Returns YES if changes were made to the network settings; returns NO otherwise.
- (BOOL)checkForNetworkSettingsChanges:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *newSTUNServerHost = [STUNServerHost stringValue];
	NSNumber *newSTUNServerPort = [NSNumber numberWithInteger:[STUNServerPort integerValue]];
	NSString *newOutboundProxyHost = [outboundProxyHost stringValue];
	NSNumber *newOutboundProxyPort = [NSNumber numberWithInteger:[outboundProxyPort integerValue]];
	
	if (![[defaults objectForKey:AKSTUNServerHost] isEqualToString:newSTUNServerHost] ||
		![[defaults objectForKey:AKSTUNServerPort] isEqualToNumber:newSTUNServerPort] ||
		![[defaults objectForKey:AKOutboundProxyHost] isEqualToString:newOutboundProxyHost] ||
		![[defaults objectForKey:AKOutboundProxyPort] isEqualToNumber:newOutboundProxyPort])
	{
		// Explicitly select Network toolbar item.
		[toolbar setSelectedItemIdentifier:[networkToolbarItem itemIdentifier]];
		
		// Show alert to the user.
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Save", @"Save button.")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button.")];
		[alert addButtonWithTitle:NSLocalizedString(@"Don't Save", @"Don't save button.")];
		[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
		[alert setMessageText:NSLocalizedString(@"Save changes to the network settings?", @"Network settings change confirmation.")];
		[alert setInformativeText:NSLocalizedString(@"New network settings will be applied immediately, all accounts will be reconnected.",
													@"Network settings change confirmation informative text.")];
		[alert beginSheetModalForWindow:[self window]
						  modalDelegate:self
						 didEndSelector:@selector(networkSettingsChangeAlertDidEnd:returnCode:contextInfo:)
							contextInfo:sender];
		return YES;
	}
	
	return NO;
}

- (void)networkSettingsChangeAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Close the sheet.
	[[alert window] orderOut:nil];
	
	if (returnCode == NSAlertSecondButtonReturn)
		return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	id sender = (id)contextInfo;
	
	if (returnCode == NSAlertFirstButtonReturn) {
		[defaults setObject:[STUNServerHost stringValue] forKey:AKSTUNServerHost];
		[defaults setObject:[NSNumber numberWithInteger:[STUNServerPort integerValue]] forKey:AKSTUNServerPort];
		[defaults setObject:[outboundProxyHost stringValue] forKey:AKOutboundProxyHost];
		[defaults setObject:[NSNumber numberWithInteger:[outboundProxyPort integerValue]] forKey:AKOutboundProxyPort];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:AKPreferenceControllerDidChangeNetworkSettingsNotification
															object:self];
	} else if (returnCode == NSAlertThirdButtonReturn) {
		[STUNServerHost setStringValue:[defaults objectForKey:AKSTUNServerHost]];
		if ([[defaults objectForKey:AKSTUNServerPort] integerValue] == 0)
			[STUNServerPort setStringValue:@""];
		else
			[STUNServerPort setIntegerValue:[[defaults objectForKey:AKSTUNServerPort] integerValue]];
		
		[outboundProxyHost setStringValue:[defaults objectForKey:AKOutboundProxyHost]];
		if ([[defaults objectForKey:AKOutboundProxyPort] integerValue] == 0)
			[outboundProxyPort setStringValue:@""];
		else
			[outboundProxyPort setIntegerValue:[[defaults objectForKey:AKOutboundProxyPort] integerValue]];
	}
	
	if ([sender isMemberOfClass:[NSToolbarItem class]]) {
		[toolbar setSelectedItemIdentifier:[sender itemIdentifier]];
		[self changeView:sender];
	} else if ([sender isMemberOfClass:[NSWindow class]])
		[sender close];
}


#pragma mark -
#pragma mark NSTableView data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	return [[defaults arrayForKey:AKAccounts] count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(NSInteger)rowIndex
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *accountDict = [[defaults arrayForKey:AKAccounts] objectAtIndex:rowIndex];
	
	return [accountDict objectForKey:[aTableColumn identifier]];
}


#pragma mark -
#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger row = [accountsTable selectedRow];

	[self populateFieldsForAccountAtIndex:row];
}


#pragma mark -
#pragma mark NSToolbar delegate

// Supply selectable toolbar items
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)aToolbar
{	
	return [NSArray arrayWithObjects:
			[generalToolbarItem itemIdentifier],
			[accountsToolbarItem itemIdentifier],
			[soundToolbarItem itemIdentifier],
			[networkToolbarItem itemIdentifier],
			nil];
}


#pragma mark -
#pragma mark NSWindow delegate

- (BOOL)windowShouldClose:(id)window
{
	BOOL networkSettingsChanged = [self checkForNetworkSettingsChanges:window];
	if (networkSettingsChanged)
		return NO;
	
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
	// Stop currently playing incoming call sound that might be selected in Preferences.
	[[[NSApp delegate] incomingCallSound] stop];
}


#pragma mark -
#pragma mark NSPopUpButton notification

- (void)popUpButtonWillPopUpNotification:(NSNotification *)notification
{
	[self updateAvailableSounds];
}

@end
