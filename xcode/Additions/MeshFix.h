//
//  MeshFix.h
//  MeshFix
//
//  Created by Antoine Palazzolo on 13/10/2020.
//

#import <Foundation/Foundation.h>

@class MDLMesh;
@interface MeshFix: NSObject
+ (MDLMesh * _Nonnull)fixMesh:(MDLMesh * _Nonnull)mesh addEdgeSubMesh:(BOOL)addEdgeSubMesh;
@end
