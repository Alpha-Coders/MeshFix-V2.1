//
//  LibTests.m
//  LibTests
//
//  Created by Antoine Palazzolo on 13/10/2020.
//

#import <XCTest/XCTest.h>
#import "MeshFix.h"
@import ModelIO;

@interface LibTests : XCTestCase

@end

@implementation LibTests

- (void)testFixSample {
    NSURL *sampleURL = [[NSBundle bundleForClass:self.class] URLForResource:@"sample_1" withExtension:@"obj"];
    
    MDLAsset *asset = [[MDLAsset alloc] initWithURL:sampleURL];
    MDLMesh *mesh = (MDLMesh *)[asset childObjectsOfClass:[MDLMesh class]].firstObject;
    MDLMesh *resultMesh = [MeshFix fixMesh:mesh];
    
    MDLAsset *resultAsset = [[MDLAsset alloc] init];
    [resultAsset addObject:resultMesh];
    
    BOOL isSuccess = [resultAsset exportAssetToURL:[NSURL fileURLWithPath:@"/Users/antoine/Desktop/tmp/result.obj"]];
    XCTAssertTrue(isSuccess);
}
@end
