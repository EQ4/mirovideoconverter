/* -*- mode: objc -*- */
//
//  RootViewController.m
//  Miro Video Converter
//
//  Created by C Worth on 2/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"
#import <Cocoa/Cocoa.h>
#import "ClickableText.h"
#import "DropBoxView.h"
#import "CWTaskWatcher.h"
#import "VideoConversionCommands.h"

#define DROPBOX_MAX_FILE_LENGTH 32
#define CONVERTING_MAX_FILE_LENGTH 45
#define CONVERTING_DONE_MAX_FILE_LENGTH 27

@implementation RootViewController
@synthesize checkForUpdates;
@synthesize rootView,convertAVideo,dragAVideo,chooseAFile1,toSelectADifferent,chooseAFile2;
@synthesize filePath,devicePicker,convertButton,filename,dropBox,window;
@synthesize finishedConverting,showFile;      
@synthesize convertingView,convertingFilename,percentDone,progressIndicator,cancelButton;
@synthesize fFMPEGOutputWindow,fFMPEGOutputTextView,conversionWatcher,speedFile;
@synthesize speedTestActive,fileSize,elapsedTime,percentPerOutputByte,videoLength, previousPercentDone;
@synthesize video,ffmpegFinishedOkayBeforeError;


-(void) awakeFromNib {
  static BOOL firstTime = YES;
  if(firstTime){
    video = [[VideoConversionCommands alloc] init];
    [devicePicker setAutoenablesItems:NO];
    [devicePicker removeAllItems];
    [devicePicker addItemWithTitle:@"Pick a Device or Video Format"];
    int i=0, j=1;
    while(deviceNames[i++]){
      [[devicePicker menu] addItem:[NSMenuItem separatorItem]]; j++;
      [devicePicker addItemWithTitle:[NSString stringWithFormat:@"%s",deviceNames[i-1]]];
      NSMenuItem *item = [devicePicker itemAtIndex:j++];
      NSDictionary *attrib =
        [[NSDictionary alloc] initWithObjectsAndKeys:
                                [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                              [NSColor blackColor], NSForegroundColorAttributeName,
                              [NSNumber numberWithFloat:-4], NSStrokeWidthAttributeName, nil];
      NSAttributedString *title =
        [[NSAttributedString alloc]
          initWithString:[NSString stringWithFormat:@"%s",deviceNames[i-1]]
          attributes:attrib];
      [attrib release];
      [item setAttributedTitle:title];
      [item setEnabled:NO];
      while(deviceNames[i++]){
        [devicePicker addItemWithTitle:[NSString stringWithFormat:@"%s",deviceNames[i-1]]];
        j++;
      }
    }
    [dropBox registerForDraggedTypes: [NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    firstTime = NO;
    [self setViewMode:ViewModeInitial];
  }
}
-(void) loadConvertingView {
  [NSBundle loadNibNamed:@"Converting" owner:self];
  [progressIndicator setMinValue:0];
  [progressIndicator setMaxValue:100];
  [NSBundle loadNibNamed:@"FFMPEGOutputWindow" owner:self];
}
-(void) setViewMode:(ViewMode)viewMode{
  switch(viewMode) {
  case ViewModeInitial:
    [self showView:ViewRoot];
    [convertAVideo setStringValue:@"Convert a Video"];
    [self revealViewControls:viewMode];
    [devicePicker selectItemAtIndex:0];
    [self maybeEnableConvertButton];
    break;
  case ViewModeWithFile:
    [self showView:ViewRoot];
    [convertAVideo setStringValue:@"Ready To Convert!"];
    [self revealViewControls:viewMode];
    [self maybeEnableConvertButton];
    break;
  case ViewModeConverting:
    [self showView:ViewConverting];
    [self revealViewControls:viewMode];
    NSString *op = [video fFMPEGOutputFileForFile:filePath andDevice:[devicePicker titleOfSelectedItem]];
    [convertingFilename setStringValue:[self formatFilename:op maxLength:CONVERTING_MAX_FILE_LENGTH]];
    [self doFFMPEGConversion];
    break;
  case ViewModeFinished:
    [self showView:ViewRoot];
    [self revealViewControls:viewMode];
    [devicePicker selectItemAtIndex:0];
    [self maybeEnableConvertButton];
    break;
  default:
    break;
  }
  currentViewMode = viewMode;
}
-(void) showView:(int)whichView {
  NSView *theView;
  switch(whichView) {
  case ViewRoot:
    theView = rootView;
    break;
  case ViewConverting:
    if(!convertingView)
      [self loadConvertingView];
    theView = convertingView;
    break;
  default:
    break;
  }
  if([window contentView] != theView){
    [[window contentView] removeFromSuperview];
    [window setContentView:theView];
  }
}
-(void) revealSubview:(NSView *)subview show:(BOOL)show {
  for(NSView *item in [rootView subviews]){
    if(item == subview && show == YES)
      return;
    if(item == subview && show == NO){
      [subview removeFromSuperview];
      return;
    }
  }
  if(show == YES)
    [rootView addSubview:subview];
}
-(void) revealViewControls:(ViewMode)viewMode{
  switch(viewMode) {
  case ViewModeInitial:
    [self revealSubview:convertAVideo      show:YES];
    [self revealSubview:dragAVideo         show:YES];
    [self revealSubview:chooseAFile1       show:YES];
    [self revealSubview:toSelectADifferent show:NO];
    [self revealSubview:chooseAFile2       show:NO];
    [self revealSubview:devicePicker       show:YES];
    [self revealSubview:convertButton      show:YES];
    [self revealSubview:filename           show:NO];
    [self revealSubview:finishedConverting show:NO];
    [self revealSubview:showFile           show:NO];
    break;
  case ViewModeWithFile:
    [self revealSubview:convertAVideo      show:YES];
    [self revealSubview:dragAVideo         show:NO];
    [self revealSubview:chooseAFile1       show:NO];
    [self revealSubview:toSelectADifferent show:YES];
    [self revealSubview:chooseAFile2       show:YES];
    [self revealSubview:devicePicker       show:YES];
    [self revealSubview:convertButton      show:YES];
    [self revealSubview:filename           show:YES];
    [self revealSubview:finishedConverting show:NO];
    [self revealSubview:showFile           show:NO];
    break;
  case ViewModeConverting:
    break;
  case ViewModeFinished:
    [self revealSubview:convertAVideo      show:NO];
    [self revealSubview:dragAVideo         show:YES];
    [self revealSubview:chooseAFile1       show:YES];
    [self revealSubview:toSelectADifferent show:NO];
    [self revealSubview:chooseAFile2       show:NO];
    [self revealSubview:devicePicker       show:YES];
    [self revealSubview:convertButton      show:YES];
    [self revealSubview:filename           show:NO];
    [self revealSubview:finishedConverting show:YES];
    [self revealSubview:showFile           show:YES];
    break;
  default:
    break;
  }
}

// Functions for root view
- (NSString *)formatFilename:(NSString *)inFile maxLength:(int)maxLength{
  NSString *outFile = [[inFile stringByAbbreviatingWithTildeInPath] lastPathComponent];
  if([outFile length] > maxLength){
    NSRange range = { 0, (maxLength-3)/2 - 1 };
    outFile = [NSString stringWithFormat:@"%@...%@",
                        [outFile substringWithRange:range],
                        [outFile substringFromIndex:[outFile length] - (maxLength-3)/2]];
  }
  return outFile;
}
- (void)dropBoxView:(DropBoxView *)dropBoxView fileDropped:(NSString *)aFilename {
  self.filePath = aFilename;
  [filename setStringValue:[self formatFilename:aFilename maxLength:DROPBOX_MAX_FILE_LENGTH]];
  [self setViewMode:ViewModeWithFile];
}
-(IBAction) chooseAFile:(id)sender {
  [[NSOpenPanel openPanel] beginSheetForDirectory:nil
                           file:nil
                           types:nil
                           modalForWindow:[self window]
                           modalDelegate:self
                           didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
                           contextInfo:nil];
}
- (void)openPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
            contextInfo:(void *)contextInfo {
  if(returnCode == NSOKButton) {
    self.filePath = [[sheet filenames] objectAtIndex:0];
    [sheet close];
    [filename setStringValue:[self formatFilename:filePath maxLength:DROPBOX_MAX_FILE_LENGTH]];
    [self setViewMode:ViewModeWithFile];
  }
}
-(IBAction) selectADevice:(id)sender {
  [self maybeEnableConvertButton];
}
-(void) maybeEnableConvertButton {
  if([devicePicker indexOfSelectedItem] != 0 && filename.alphaValue > 0)
    [convertButton setEnabled:YES];
  else
    [convertButton setEnabled:NO];
}
-(IBAction) convertButtonClick:(id)sender {
  [self setViewMode:ViewModeConverting];
}
-(IBAction) showFileClick:(id)sender {
  [[NSWorkspace sharedWorkspace] openFile:[filePath stringByDeletingLastPathComponent] withApplication:@"Finder"];
}

// Functions for converting view
-(IBAction) fFMPEGButtonClick:(id)sender {
  [fFMPEGOutputWindow makeKeyAndOrderFront:self];
}
-(IBAction) cancelButtonClick:(id)sender {
  int iResponse = 
    NSRunAlertPanel(@"Cancel Conversion",@"Are you sure you want cancel the conversion?",
                    @"No", @"Yes", /*third button*/nil/*,args for a printf-style msg go here*/);
    switch(iResponse) {
    case NSAlertDefaultReturn:
      break;
    case NSAlertAlternateReturn:
      [conversionWatcher requestFinishWithStatus:EndStatusCancel];
      break;
    default:
      break;
    }
}

// Functions for ffmpeg conversion handling
-(void) doFFMPEGConversion {
  // this is a separate fn in case we want to launch an initial run first
  // prev ran speedtest
  self.videoLength = 0;
  [self doConversion];
}
-(void) doConversion {
  self.previousPercentDone = 0;
  [progressIndicator startAnimation:self];
  [progressIndicator setIndeterminate:YES];
  [percentDone setStringValue:@"Converting..."];
  [cancelButton setEnabled:YES];
  [self startAConversion:filePath forDevice:[devicePicker titleOfSelectedItem]];
}
-(void) startAConversion:(NSString *)file forDevice:(NSString *)device {
  self.ffmpegFinishedOkayBeforeError = NO;
  // initialize textbox for FFMPEG output window
  NSTextStorage *storage = [[[fFMPEGOutputTextView textContainer] textView] textStorage];
  NSAttributedString *string =
    [[NSAttributedString alloc]
      initWithString:[NSString stringWithFormat:@"%@ %@\n",[[video fFMPEGLaunchPathForDevice:device] lastPathComponent],
                               [[video fFMPEGArgumentsForFile:file andDevice:device] componentsJoinedByString:@" "]]];
  [storage setAttributedString:string];
  [string release];
  CWTaskWatcher *aWatcher = [[CWTaskWatcher alloc] init];
  self.conversionWatcher = aWatcher;
  [aWatcher release];
  conversionWatcher.delegate = self;
  conversionWatcher.textStorage = storage;
  [conversionWatcher startTask:
                       [video fFMPEGLaunchPathForDevice:device]
                     withArgs:[video fFMPEGArgumentsForFile:file andDevice:device]
                     andProgressFile:[video fFMPEGOutputFileForFile:file andDevice:device]];
}
-(void) convertingDone:(TaskEndStatus)status {
  [progressIndicator stopAnimation:self];
  videoLength = 0;
  percentPerOutputByte = 0;
  elapsedTime = 0;
  fileSize = 0;
  if(status == EndStatusError && self.ffmpegFinishedOkayBeforeError == YES)
    status = EndStatusOK;
  int iResponse;
  switch(status) {
  case EndStatusOK:
    [finishedConverting setStringValue:
			  [NSString stringWithFormat:@"Finished converting %@",
				    [self formatFilename:[video fFMPEGOutputFileForFile:filePath andDevice:[devicePicker titleOfSelectedItem]]
					  maxLength:CONVERTING_DONE_MAX_FILE_LENGTH]]];
    [self setViewMode:ViewModeFinished];
    break;
  case EndStatusError:  
    iResponse = NSRunAlertPanel(@"Conversion Failed", @"Your file could not be converted.",
                                    @"OK", @"Show Output", nil);
    if(iResponse == NSAlertAlternateReturn)
      [fFMPEGOutputWindow makeKeyAndOrderFront:self];
  case EndStatusCancel:
    [self setViewMode:ViewModeWithFile];
    break;
  }
}
-(void) doSpeedTest {
  self.speedTestActive = YES;
  self.previousPercentDone = 0;
  [progressIndicator startAnimation:self];
  [progressIndicator setIndeterminate:YES];
  [percentDone setStringValue:@"Initializing..."];
  [cancelButton setEnabled:NO];
  [self startAConversion:filePath forDevice:@" Playstation Portable (PSP)"];
}
-(void) finishUpSpeedTest {
  self.speedTestActive = NO;
}
- (void)cwTaskWatcher:(CWTaskWatcher *)cwTaskWatcher ended:(TaskEndStatus)status {
  if(self.speedTestActive){
    [self finishUpSpeedTest];
    if(status == EndStatusOK){
      [self doConversion];
      return;
    }
  }
  [self convertingDone:status];
}
- (void)cwTaskWatcher:(CWTaskWatcher *)cwTaskWatcher updateFileInfo:(NSDictionary *)dict {
  self.fileSize = [[dict objectForKey:@"filesize"] intValue];;
  self.elapsedTime = [[dict objectForKey:@"elapsedTime"] floatValue];
}
- (NSString *)cwTaskWatcher:(CWTaskWatcher *)cwTaskWatcher censorOutput:(NSString *)input {
  char *p = [input UTF8String], *q;
  char *str = malloc([input length] + 10);
  strncpy(str,p,[input length]);
  if(strlen(str) > strlen("pointer being freed was not allocated"))
    q = strstr(str,"pointer being freed was not allocated");
  else
    return input;
  if(!q) return input;
  for(;q >= str && *q != '\n'; q--);
  if(q==str) sprintf(q,"[sic]\n");
  else sprintf(q+1,"[sic]\n");
  NSString *output = [NSString stringWithFormat:@"%s",str];
  free(str);
  return output;
}

- (void)cwTaskWatcher:(CWTaskWatcher *)cwTaskWatcher updateString:(NSString *)output {
  static BOOL aboutToReadDuration = NO;

  [progressIndicator startAnimation:self];
  
  char buf[[output length]+1]; NSUInteger usedLength;
  [output getBytes:buf maxLength:[output length] usedLength:&usedLength
          encoding:NSASCIIStringEncoding options:NSStringEncodingConversionAllowLossy
          range:NSMakeRange(0,[output length]) remainingRange:nil];
  if(usedLength == 0)
    return;
  buf[usedLength] = 0;
  char *p = 0;
  if(self.videoLength == 0) {
    char durStr[256];
    if(![[devicePicker titleOfSelectedItem] compare:@" Theora"])
      strcpy(durStr,"\"duration\":");
    else
      strcpy(durStr,"Duration:");
    // see if durStr string is in this input block, and if so, if
    // duration info is as well
    if(strlen(buf) >= strlen(durStr)) {
      p = strstr(buf,durStr);
      if(p && strlen(p) >= strlen(durStr) + 9) {
        p += strlen(durStr) + 1;
        aboutToReadDuration = YES;
      }
    }
    if(p==0)
      p = buf;
    if(aboutToReadDuration){
      self.videoLength = 0;
      if(strstr(durStr,"Dur")){
        //ffmpeg
        float components[3];
        sscanf(p,"%f:%f:%f",components,components+1, components+2);
        for(int i=2, mult=1; i>=0; i--, mult *= 60)
          self.videoLength += components[i]  * mult;
      } else {
        //theora
        float dur;
        sscanf(p,"%f",&dur);
        self.videoLength = dur;
      }
      aboutToReadDuration = NO;
      if(self.speedTestActive)
	[conversionWatcher requestFinishWithStatus:EndStatusOK];
      return;
    } else {
      // if duration info was not in this block, see if durStr was
      // (this often happens for ffmpeg)
      if(strlen(buf) >= strlen(durStr) && strstr(buf,durStr))
	aboutToReadDuration = YES;
    }
  }

  // time updates: time= for ffmpeg
  float curTime = 0;
  if(strlen(buf) > strlen("time=")+1 && (p=strstr(buf,"time=")))
    sscanf(p+strlen("time="),"%f", &curTime);
  // "position": for ffpeg2theora
  if(strlen(buf) > strlen("\"position\":")+1 && (p=strstr(buf,"\"position\":")))
    sscanf(p+strlen("\"position\":"),"%f", &curTime);
  // update percent done
  if(self.videoLength && !self.speedTestActive){
    if(curTime) {
      float percent = curTime / self.videoLength * 100;
      if(previousPercentDone && percent - previousPercentDone > 50)
        percent = previousPercentDone;
      if(percent > 100) percent = 99;
      previousPercentDone = percent;
      [progressIndicator setIndeterminate:NO];
      [progressIndicator setDoubleValue:percent];
      [percentDone setStringValue:[NSString stringWithFormat:@"%i%% done",(int)percent]];
    }
  }

  // Check for libxvid malloc error at end, may have completed successfully
  if(strlen(buf) > strlen("muxing overhead") && (p=strstr(buf,"muxing overhead")))
    self.ffmpegFinishedOkayBeforeError = YES;
  return;
}
@end

