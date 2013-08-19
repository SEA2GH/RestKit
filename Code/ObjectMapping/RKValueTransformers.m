//
//  RKValueTransformers.m
//  RestKit
//
//  Created by Blake Watters on 11/26/12.
//  Copyright (c) 2012 RestKit. All rights reserved.
//

#import "RKValueTransformers.h"
#import "RKMacros.h"
#import "RKLog.h"
#import "RKErrors.h"

@interface RKValueTransformer ()
@property (nonatomic, copy) BOOL (^validationBlock)(Class, Class);
@property (nonatomic, copy) BOOL (^transformationBlock)(id, id *, NSError **);
@end

@implementation RKValueTransformer

+ (instancetype)valueTransformerWithValidationBlock:(BOOL (^)(Class sourceClass, Class destinationClass))validationBlock
                                transformationBlock:(BOOL (^)(id inputValue, id *outputValue, NSError **error))transformationBlock
{
    if (! transformationBlock) [NSException raise:NSInvalidArgumentException format:@"The `transformationBlock` cannot be `nil`."];
    RKValueTransformer *valueTransformer = [self new];
    valueTransformer.validationBlock = validationBlock;
    valueTransformer.transformationBlock = transformationBlock;
    return valueTransformer;
}

- (BOOL)transformValue:(id)inputValue toValue:(id *)outputValue error:(NSError **)error
{
    return self.transformationBlock(inputValue, outputValue, error);
}

- (BOOL)validateTransformationFromClass:(Class)sourceClass toClass:(Class)destinationClass
{
    if (self.validationBlock) return self.validationBlock(sourceClass, destinationClass);
    else return YES;
}

#pragma mark Default Transformers

+ (instancetype)singletonValueTransformer:(RKValueTransformer * __strong *)valueTransformer
                                onceToken:(dispatch_once_t *)onceToken
                                       validationBlock:(BOOL (^)(Class sourceClass, Class destinationClass))validationBlock
                                   transformationBlock:(BOOL (^)(id inputValue, id *outputValue, NSError **error))transformationBlock
{
    dispatch_once(onceToken, ^{
        *valueTransformer = [RKValueTransformer valueTransformerWithValidationBlock:validationBlock transformationBlock:transformationBlock];
    });
    return *valueTransformer;
}

+ (instancetype)stringToURLValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSURL class]]) ||
                ([sourceClass isSubclassOfClass:[NSURL class]] && [destinationClass isSubclassOfClass:[NSString class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSURL class]]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSURL *URL = [NSURL URLWithString:inputValue];
            RKValueTransformerTestTransformation(URL != nil, error, @"Failed transformation of '%@' to URL: the string is malformed and cannot be transformed to an `NSURL` representation.", inputValue);
            *outputValue = URL;
        } else if ([inputValue isKindOfClass:[NSURL class]]) {
            *outputValue = [(NSURL *)inputValue absoluteString];
        }
        return YES;
    }];
}

+ (instancetype)numberToStringValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSNumber class]] && [destinationClass isSubclassOfClass:[NSString class]]) ||
                ([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSString class] ]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSString *lowercasedString = [inputValue lowercaseString];
            NSSet *trueStrings = [NSSet setWithObjects:@"true", @"t", @"yes", @"y", nil];
            NSSet *booleanStrings = [trueStrings setByAddingObjectsFromSet:[NSSet setWithObjects:@"false", @"f", @"no", @"n", nil]];
            if ([booleanStrings containsObject:lowercasedString]) {
                // Handle booleans encoded as Strings
                *outputValue = [NSNumber numberWithBool:[trueStrings containsObject:lowercasedString]];
            } else if ([lowercasedString rangeOfString:@"."].location != NSNotFound) {
                // String -> Floating Point Number
                // Only use floating point if needed to avoid losing precision on large integers
                *outputValue = [NSNumber numberWithDouble:[lowercasedString doubleValue]];
            } else {
                // String -> Signed Integer
                *outputValue = [NSNumber numberWithLongLong:[lowercasedString longLongValue]];
            }
        } else if ([inputValue isKindOfClass:[NSNumber class]]) {
            if (NSClassFromString(@"__NSCFBoolean") && [inputValue isKindOfClass:NSClassFromString(@"__NSCFBoolean")]) {
                *outputValue = [inputValue boolValue] ? @"true" : @"false";
            } else if (NSClassFromString(@"NSCFBoolean") && [inputValue isKindOfClass:NSClassFromString(@"NSCFBoolean")]) {
                *outputValue = [inputValue boolValue] ? @"true" : @"false";
            } else {
                *outputValue = [inputValue stringValue];
            }
        }
        return YES;
    }];
}

+ (instancetype)dateToNumberValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSNumber class]] && [destinationClass isSubclassOfClass:[NSDate class]]) ||
                ([sourceClass isSubclassOfClass:[NSDate class]] && [destinationClass isSubclassOfClass:[NSNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSDate class]]), error);
        if ([inputValue isKindOfClass:[NSNumber class]]) {
            *outputValue = [NSDate dateWithTimeIntervalSince1970:[inputValue doubleValue]];
        } else if ([inputValue isKindOfClass:[NSDate class]]) {
            *outputValue = [NSNumber numberWithDouble:[inputValue timeIntervalSince1970]];
        }
        return YES;
    }];
}

+ (instancetype)arrayToOrderedSetValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSArray class]] && [destinationClass isSubclassOfClass:[NSOrderedSet class]]) ||
                ([sourceClass isSubclassOfClass:[NSOrderedSet class]] && [destinationClass isSubclassOfClass:[NSArray class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSArray class], [NSOrderedSet class]]), error);
        if ([inputValue isKindOfClass:[NSArray class]]) {
            *outputValue = [NSOrderedSet orderedSetWithArray:inputValue];
        } else if ([inputValue isKindOfClass:[NSOrderedSet class]]) {
            *outputValue = [inputValue array];
        }
        return YES;
    }];
}

+ (instancetype)arrayToSetValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSArray class]] && [destinationClass isSubclassOfClass:[NSSet class]]) ||
                ([sourceClass isSubclassOfClass:[NSSet class]] && [destinationClass isSubclassOfClass:[NSArray class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSSet class], [NSArray class]]), error);
        if ([inputValue isKindOfClass:[NSArray class]]) {
            *outputValue = [NSSet setWithArray:inputValue];
        } else if ([inputValue isKindOfClass:[NSSet class]]) {
            *outputValue = [inputValue allObjects];
        }
        return YES;
    }];
}

+ (instancetype)decimalNumberToStringValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSDecimalNumber class]] && [destinationClass isSubclassOfClass:[NSString class]]) ||
                ([sourceClass isSubclassOfClass:[NSString class]] && [destinationClass isSubclassOfClass:[NSDecimalNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSString class], [NSDecimalNumber class]]), error);
        if ([inputValue isKindOfClass:[NSString class]]) {
            NSDecimalNumber *decimalNumber = [NSDecimalNumber decimalNumberWithString:inputValue];
            RKValueTransformerTestTransformation(! [decimalNumber isEqual:[NSDecimalNumber notANumber]], error, @"Failed transformation of '%@' to `NSDecimalNumber`: the input string was transformed into Not a Number (NaN) value.", inputValue);
            *outputValue = decimalNumber;
        } else if ([inputValue isKindOfClass:[NSDecimalNumber class]]) {
            *outputValue = [inputValue stringValue];
        }
        return YES;
    }];
}

+ (instancetype)decimalNumberToNumberValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass isSubclassOfClass:[NSDecimalNumber class]] && [destinationClass isSubclassOfClass:[NSNumber class]]) ||
                ([sourceClass isSubclassOfClass:[NSNumber class]] && [destinationClass isSubclassOfClass:[NSDecimalNumber class]]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, (@[ [NSNumber class], [NSDecimalNumber class]]), error);
        if ([inputValue isKindOfClass:[NSNumber class]]) {
            *outputValue = [NSDecimalNumber decimalNumberWithDecimal:[inputValue decimalValue]];
        } else if ([inputValue isKindOfClass:[NSDecimalNumber class]]) {
            *outputValue = inputValue;
        }
        return YES;
    }];
}

+ (instancetype)nullValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:nil transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, [NSNull class], error);
        *outputValue = nil;
        return YES;
    }];
}

+ (instancetype)keyedArchivingValueTransformer
{
    static dispatch_once_t onceToken;
    static RKValueTransformer *valueTransformer;
    return [self singletonValueTransformer:&valueTransformer onceToken:&onceToken validationBlock:^BOOL(__unsafe_unretained Class sourceClass, __unsafe_unretained Class destinationClass) {
        return (([sourceClass conformsToProtocol:@protocol(NSCoding)] && [destinationClass isSubclassOfClass:[NSData class]]) ||
                ([sourceClass isSubclassOfClass:[NSData class]] && [destinationClass conformsToProtocol:@protocol(NSCoding)]));
    } transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
        if ([inputValue isKindOfClass:[NSData class]]) {
            id unarchivedValue = nil;
            @try {
                unarchivedValue = [NSKeyedUnarchiver unarchiveObjectWithData:inputValue];
            }
            @catch (NSException *exception) {
                NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"An `%@` exception was encountered while attempting to unarchive the given inputValue.", [exception name]], @"exception": exception };
                *error = [NSError errorWithDomain:RKErrorDomain code:RKValueTransformationErrorTransformationFailed userInfo:userInfo];
                return NO;
            }
            *outputValue = unarchivedValue;
        } else if ([inputValue conformsToProtocol:@protocol(NSCoding)]) {
            *outputValue = [NSKeyedArchiver archivedDataWithRootObject:inputValue];
        } else {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Expected an `inputValue` of type `NSData` or conforming to `NSCoding`, but got a `%@` which does not satisfy these expectation.", [inputValue class]] };
            *error = [NSError errorWithDomain:RKErrorDomain code:RKValueTransformationErrorUntransformableInputValue userInfo:userInfo];
            return NO;
        }
        RKValueTransformerTestInputValueIsKindOfClass(inputValue, [NSNull class], error);
        *outputValue = nil;
        return YES;
    }];
}

+ (instancetype)stringToDateValueTransformerWithFormatter:(NSFormatter *)stringToDateFormatter
{
    
}

+ (instancetype)dateToStringValueTransformerWithFormatter:(NSFormatter *)dateToStringFormatter
{
    
}

+ (RKCompoundValueTransformer *)defaultValueTransformer
{
    return nil;
}

@end

@interface RKCompoundValueTransformer ()
@property (nonatomic, strong) NSMutableArray *valueTransformers;
@end

@implementation RKCompoundValueTransformer

+ (instancetype)compoundValueTransformerWithValueTransformers:(NSArray *)valueTransformers
{
    // TODO: Assert that all objects are value transformers;
    RKCompoundValueTransformer *valueTransformer = [self new];
    valueTransformer.valueTransformers = [valueTransformers mutableCopy];
    return valueTransformer;
}

- (void)addValueTransformer:(id<RKValueTransforming>)valueTransformer
{
    // TODO: Assert that the given value adopts the protocol. not `nil`.
    [self.valueTransformers addObject:valueTransformer];
}

- (void)removeValueTransformer:(id<RKValueTransforming>)valueTransformer
{
    // TODO: Assert that the given value adopts the protocol. not `nil`.
    [self.valueTransformers removeObject:valueTransformer];
}

// performs a move or insert
- (void)insertValueTransformer:(id<RKValueTransforming>)valueTransformer atIndex:(NSUInteger)index
{
    // TODO: Assert that the given value adopts the protocol. not `nil`.
    [self.valueTransformers insertObject:valueTransformer atIndex:index];
}

- (NSUInteger)numberOfValueTransformers
{
    return [self.valueTransformers count];
}

// Do we need/want both??
- (NSArray *)valueTransformersForTransformingFromClass:(Class)sourceClass toClass:(Class)destinationClass
{
    
}

- (NSArray *)valueTransformersForTransformingValue:(id)value toClass:(Class)destinationClass
{
    
}

#pragma mark RKValueTransforming

#pragma mark NSCopying

#pragma mark NSFastEnumeration

@end

//
//// Set up the built-in transformers
//+ (void)initialize
//{
//    [super initialize];
//    if ([RKValueTransformer class] != self) return;
//    [[self defaultStringToURLTransformer] _register];
//    [[self defaultStringToNumberTransformer] _register];


//    [[self defaultNumberToDateTransformer] _register];
//    [[self defaultOrderedSetToArrayTransformer] _register];
//    [[self defaultSetToArrayTransformer] _register];
//    [[self defaultStringToDecimalNumberTransformer] _register];
//    [[self defaultNumberToDecimalNumberTransformer] _register];
//    [[self defaultObjectToDataTransformer] _register];
//    [[self defaultNullTransformer] _register];
//    [[self identityTransformer] _register];
//}
//
//
//+ (instancetype)identityTransformer
//{
//    static RKValueTransformer *identityTransformer;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        identityTransformer = [RKIdentityValueTransformer valueTransformerWithSourceClass:[NSObject class] destinationClass:[NSObject class] transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
//            *outputValue = inputValue;
//            return YES;
//        } reverseTransformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
//            *outputValue = inputValue;
//            return YES;
//        }];
//    });
//    return identityTransformer;
//}
//
//+ (instancetype)stringValueTransformer
//{
//    static RKValueTransformer *stringValueTransformer;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        stringValueTransformer = [RKStringValueTransformer valueTransformerWithSourceClass:[NSObject class] destinationClass:[NSString class] transformationBlock:^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
//            *outputValue = [inputValue stringValue];
//            return YES;
//        } reverseTransformationBlock:nil];
//    });
//    return stringValueTransformer;
//}
//
//@end
//
//// Implementation lives in RKObjectMapping.m at the moment
//NSDate *RKDateFromStringWithFormatters(NSString *dateString, NSArray *formatters);
//
//@implementation RKDateToStringValueTransformer
//
//+ (Class)transformedValueClass
//{
//    return [NSDate class];
//}
//
//+ (BOOL)allowsReverseTransformation
//{
//    return YES;
//}
//
//+ (instancetype)dateToStringValueTransformerWithDateToStringFormatter:(NSFormatter *)dateToStringFormatter stringToDateFormatters:(NSArray *)stringToDateFormatters
//{
//    return [[self alloc] initWithDateToStringFormatter:dateToStringFormatter stringToDateFormatters:stringToDateFormatters];
//}
//
//- (id)initWithDateToStringFormatter:(NSFormatter *)dateToStringFormatter stringToDateFormatters:(NSArray *)stringToDateFormatters
//{
//    self = [super initWithSourceClass:[NSDate class] destinationClass:[NSString class] transformationBlock:nil reverseTransformationBlock:nil];
//    if (self) {
//        self.dateToStringFormatter = dateToStringFormatter;
//        self.stringToDateFormatters = stringToDateFormatters;
//        __weak id weakSelf = self;
//        self.transformationBlock = ^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
//            RKDateToStringValueTransformer *strongSelf = weakSelf;
//            NSCAssert(strongSelf.dateToStringFormatter, @"Cannot transform an `NSDate` to an `NSString`: dateToStringFormatter is nil");
//            if (!strongSelf.dateToStringFormatter) return NO;
//            @synchronized(strongSelf.dateToStringFormatter) {
//                *outputValue = [strongSelf.dateToStringFormatter stringForObjectValue:inputValue];
//            }
//            return YES;
//        };
//        self.reverseTransformationBlock = ^BOOL(id inputValue, __autoreleasing id *outputValue, NSError *__autoreleasing *error) {
//            RKDateToStringValueTransformer *strongSelf = weakSelf;
//            NSCAssert(strongSelf.stringToDateFormatters, @"Cannot transform an `NSDate` to an `NSString`: stringToDateFormatters is nil");
//            if (strongSelf.stringToDateFormatters.count <= 0) return NO;
//            *outputValue = RKDateFromStringWithFormatters(inputValue, strongSelf.stringToDateFormatters);
//            return YES;
//        };
//    }
//    return self;
//}
//
//- (instancetype)reverseTransformer
//{
//    RKDateToStringValueTransformer *reverse = [[RKDateToStringValueTransformer alloc] initWithDateToStringFormatter:self.dateToStringFormatter stringToDateFormatters:self.stringToDateFormatters];
//    reverse.destinationClass = self.sourceClass;
//    reverse.sourceClass = self.destinationClass;
//    reverse.transformationBlock = self.reverseTransformationBlock;
//    reverse.reverseTransformationBlock = self.transformationBlock;
//    return reverse;
//}
//
//- (id)init
//{
//    return [self initWithDateToStringFormatter:nil stringToDateFormatters:nil];
//}
//
//@end
//
//BOOL RKIsMutableTypeTransformation(id value, Class destinationType);
//
//@implementation RKIdentityValueTransformer
//
//- (BOOL)canTransformClass:(Class)sourceClass toClass:(Class)destinationClass
//{
//    if (RKIsMutableTypeTransformation(nil, destinationClass)) {
//        return [self canTransformClass:sourceClass toClass:[destinationClass superclass]];
//    }
//    if ([sourceClass isSubclassOfClass:destinationClass] || [destinationClass isSubclassOfClass:sourceClass]) return YES;
//    else return NO;
//}
//
//@end
//
//@implementation RKStringValueTransformer
//
//- (BOOL)canTransformClass:(Class)sourceClass toClass:(Class)destinationClass
//{
//    if ([sourceClass instancesRespondToSelector:@selector(stringValue)]) return YES;
//    return NO;
//}
//
//@end

@implementation RKDateToStringValueTransformer
@end
