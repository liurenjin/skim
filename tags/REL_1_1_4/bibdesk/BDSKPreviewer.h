//  BDSKPreviewer.h

//  Created by Michael McCracken on Tue Jan 29 2002.
/*
 This software is Copyright (c) 2002,2003,2004,2005
 Michael O. McCracken. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in
    the documentation and/or other materials provided with the
    distribution.

 - Neither the name of Michael O. McCracken nor the names of any
    contributors may be used to endorse or promote products derived
    from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*! @header BDSKPreviewer.h
    @discussion Contains class declaration for the Tex task manager and preview window.
*/

#import <Cocoa/Cocoa.h>
#import "PDFImageView.h"
#import "BibPrefController.h"
#import <OmniFoundation/OFWeakRetainConcreteImplementation.h>

#ifdef BDSK_USING_TIGER
#import "BDSKZoomablePDFView.h"
#endif

@class BibDocument;
@class BDSKPreviewMessageQueue;

/*!
    @class BDSKPreviewer
    @abstract TeX task manager and preview window controller
    @discussion ...
*/
@interface BDSKPreviewer : NSWindowController <OFMessageQueueDelegate, OFWeakRetain> {
    NSString *usertexTemplatePath;
    NSString *texTemplatePath;
    NSString *finalPDFPath;
    NSString *nopreviewPDFPath;
    NSString *tmpBibFilePath;
    NSString *rtfFilePath;
    NSString *applicationSupportPath;
    NSString *binPathDir;
    
    id pdfView;
    IBOutlet NSSplitView *splitView;
    IBOutlet PDFImageView *imagePreviewView;
    IBOutlet NSTextView *rtfPreviewView;
    IBOutlet NSTabView *tabView;
    
    BDSKPreviewMessageQueue *messageQueue;
}
/*!
    @method sharedPreviewer
    @abstract accesses the single object
 @result Pointer to the single BDSKPreviewer instance.
    
*/
+ (BDSKPreviewer *)sharedPreviewer;

/*!
    @method PDFFromString:
    @abstract given a string, displays the PDF preview
    @discussion takes the string as a bibtex entry or entries, inserts appropriate values into a template, runs LaTeX, BibTeX, LaTeX, LateX, and loads the file as PDF into its imageview
    @param str the bibtex source
 @result YES indicates success... <em>might not be correct - I don't use the result</em>
*/
- (BOOL)PDFFromString:(NSString *)str;

/*!
 @method writeTeXFile
 @abstract Writes the TeX file to use for the preview
 @discussion -
 */
- (BOOL)writeTeXFile;

/*!
 @method writeBibTeXFile:
 @abstract Writes the BibTeX file to use for the preview
 @discussion -
 @param str The BibTeX string to write after the template
 */
- (BOOL)writeBibTeXFile:(NSString *)str;

/*!
 @method previewTexTasks:
 @abstract given a filename as string, run NSTasks for LaTeX on it
 @discussion assumes that the .tex file is created elsewhere, and the working directory is Application Support/BibDesk
 @param fileName the filename as a string
 */
- (BOOL)previewTexTasks:(NSString *)fileName;


/*!
@method PDFDataFromString:
    @abstract given a string, gives PDF of the preview as NSData
    @discussion takes the string as a bibtex entry or entries, inserts appropriate values into a template, runs LaTeX, BibTeX, LaTeX, LateX, and returns the PDF file as an NSData object.
 @param str  The bibtex source
 @result pointer to autoreleased (?) NSData object that contains the PDF Data of the preview
*/
- (NSData *)PDFDataFromString:(NSString *)str;

/*!
 @method rtfStringPreview:
 @abstract gives an RTF of the file at rtfFilePath as an NSAttributedString
 @discussion generally used to read the rtf file generated by latex2rtf
 @param rtfFilePath the path to the rtf file
 @result pointer to the NSString with the RTF data
*/
- (NSAttributedString *)rtfStringPreview:(NSString *)filePath;

/*!
 @method RTFPreviewData:
 @abstract gives the RTF of the preview as NSData
 @discussion reads the rtf file generated by latex2rtf
 @param str the bibtex source
 @result pointer to the NSData with the RTF data
*/

- (NSData *)RTFPreviewData;

/*!
 @method displayRTFPreviewFromData:
 @abstract puts data in a textview
 @discussion takes rtfDataFromString, and puts it into a textview in the preview panel
 @param str the RTF string
 @result should return Y if successful...
*/
- (BOOL)displayRTFPreviewFromData:(NSData *)rtfdata;

/*!
    @method     resetPreviews
    @abstract   Set the preview views to a no-selection state.
    @discussion Presently, this uses a file called nopreview.pdf which lives in the Resources folder
		for the PDFImageView, and the same text is entered in the text view (RTF preview view).
*/
- (void)resetPreviews;

/*!
    @method     performDrawing
    @abstract   Draws the previews in their appropriate views, in a thread-safe manner.
    @discussion (comprehensive description)
*/
- (void)performDrawing;
@end
