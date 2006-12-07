//
//  BDSKFormatParser.h
//  Bibdesk
//
//  Created by Christiaan Hofman on 17/4/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BibItem;

@interface BDSKFormatParser : NSObject {
	NSCharacterSet *validSpecifierChars;
	NSCharacterSet *validUniqueSpecifierChars;
	NSCharacterSet *validEscapeSpecifierChars;
	NSCharacterSet *validArgSpecifierChars;
	NSCharacterSet *validOptArgSpecifierChars;
}

+ (BDSKFormatParser *)sharedParser;

/*!
    @method parseFormat:forField:ofItem:
    @abstract Generates a value for a field in a type based on the receiver and the format string
    @discussion -
    @param format The format string to use
    @param fieldName The name of the field (e.g. "Author")
    @param pub The BibItem for which to parse the format
	@result The parsed format string 
*/
- (NSString *)parseFormat:(NSString *)format forField:(NSString *)fieldName ofItem:(BibItem *)pub;

/*!
    @method uniqueString:suffix:forField:ofItem:numberOfChars:from:to:force:
    @abstract Tries to return a unique string value for a field in a type, by adding characters from a range
    @discussion -
    @param baseString The string to base the unique string on
    @param suffix The string to add as a suffix to the unique string
    @param fieldName The name of the field (e.g. "Author")
	@param pub The item for which to get a unique value
	@param number The number of characters to add, when force is YES the minimal number
	@param fromChar The first character in the range to use
	@param toChar The last character of the range to use
	@param force Determines whether to allow for more characters to force a unique key
	@result A string value for field in type that starts with baseString and is unique when force is YES
*/
- (NSString *)uniqueString:(NSString *)baseString 
					suffix:(NSString *)suffix
				  forField:(NSString *)fieldName 
					ofItem:(BibItem *)pub
			 numberOfChars:(unsigned int)number 
					  from:(unichar)fromChar 
						to:(unichar)toChar 
					 force:(BOOL)force;

/*!
    @method stringIsValid:forField:ofItem:
    @abstract Returns whether a string is a valid as a value for a field in a type
    @discussion -
	@param proposedStr The trial string to check for validity
    @param fieldName The name of the field (e.g. "Author")
	@param pub The item for which to check validity
*/
- (BOOL)stringIsValid:(NSString *)proposedStr forField:(NSString *)fieldName ofItem:(BibItem *)pub;

/*!
 @method stringBySanitizingString:forField:inFieldType:
 @abstract Sanitize a string to use in a generated value for a field and type
 @discussion Creates a string containing only a strictly valid set of characters, by converting some characters and removing others. This uses invalidCharactersForField:inFileType:. It is used for the validation of the format string.  
 @param string The unsanitized string
 @param fieldName The name of the field (e.g. "Author")
 @param type The reference type (e.g. BibTeX, RIS)
 @result The sanitized string
*/
- (NSString *)stringBySanitizingString:(NSString *)string forField:(NSString *)fieldName inFileType:(NSString *)type;

/*!
 @method stringByStrictlySanitizingString:forField:inFieldType:
 @abstract Sanitize a string to use in a generated value for a field and type
 @discussion Creates a string containing only a valid set of characters, by converting some characters and removing others. This uses strictInvalidCharactersForField:inFileType:. It is used for the parsing of the format string. 
 @param string The unsanitized string
 @param fieldName The name of the field (e.g. "Author")
 @param type The reference type (e.g. BibTeX, RIS)
 @result The sanitized string
*/
- (NSString *)stringByStrictlySanitizingString:(NSString *)string forField:(NSString *)fieldName inFileType:(NSString *)type;

/*!
 @method stringBySanitizedCiteKeyString
 @abstract Validate a format string to use for a field in a type
 @discussion Checks for valid specifiers and calls stringBySanitizingString:forField:inFieldType: on other parts of the string. Might change the format string.
 @param formatString The format string to check
 @param fieldName The name of the field (e.g. "Author")
 @param type The reference type (e.g. BibTeX, RIS)
 @param error An error string returned when the format is not valid
 @result The sanitized string
*/
- (BOOL)validateFormat:(NSString **)formatString forField:(NSString *)fieldName inFileType:(NSString *)type error:(NSString **)error;

/*!
 @method requiredFieldsForFormat
 @abstract Finds all field names used in a format string
 @discussion -
 @param formatString The format string to check
 @result Array of required field names
*/
- (NSArray *)requiredFieldsForFormat:(NSString *)formatString;

@end
