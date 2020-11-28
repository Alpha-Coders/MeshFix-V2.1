//
//  MeshFix.h
//  MeshFix
//
//  Created by Antoine Palazzolo on 13/10/2020.
//

#import "MeshFix.h"
#import "tmesh.h"
#import "list.h"
#import <ModelIO/ModelIO.h>

using namespace T_MESH;

@implementation MeshFix
+ (void)initialize {
    TMesh::init();
    TMesh::quiet = true;
}

+ (MDLMesh * _Nonnull)fixMesh:(MDLMesh * _Nonnull)mesh {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:10];
    
    NSUInteger submeshIndex = [[mesh submeshes] indexOfObjectPassingTest:^BOOL(MDLSubmesh * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.geometryType == MDLGeometryTypeTriangles;
    }];
    if (submeshIndex == NSNotFound) { @throw @"triangle submesh not found"; }

    MDLSubmesh *submesh = mesh.submeshes[submeshIndex];
    MDLMeshBufferMap * meshFaceIndices = [[submesh indexBufferAsIndexType:MDLIndexBitDepthUInt32] map];
    MDLVertexAttributeData *positionAttributes = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributePosition asFormat:MDLVertexFormatFloat3];
    MDLVertexAttributeData *colorAttributes = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributeColor asFormat:MDLVertexFormatFloat3];
    progress.completedUnitCount = 1;
    
    Basic_TMesh tin;
    
    NSUInteger vertexCount = mesh.vertexCount;
    ExtVertex **var = (ExtVertex **)malloc(sizeof(ExtVertex *)*vertexCount);
    
    for (NSUInteger vertexIndex = 0; vertexIndex < vertexCount; vertexIndex++) {
        Float32 * positionBuffer = (Float32 *)((UInt8 *)positionAttributes.dataStart + vertexIndex * positionAttributes.stride);
        Vertex *v = tin.newVertex(positionBuffer[0], positionBuffer[1], positionBuffer[2]);
        if (colorAttributes != nil) {
            Float32 * colorBuffer = (Float32 *)((UInt8 *)colorAttributes.dataStart + vertexIndex * colorAttributes.stride);
            v->color = new Color(colorBuffer[0], colorBuffer[1], colorBuffer[2]);
        } else {
            v->color = NULL;
        }
        tin.V.appendTail(v);
        var[vertexIndex] = new ExtVertex(v);
    }
    progress.completedUnitCount = 2;

    NSUInteger trianglesCount = submesh.indexCount/3;
    for (NSUInteger faceIndex = 0; faceIndex < trianglesCount; faceIndex++) {
        UInt32 * indexBuffer = ((UInt32 *)meshFaceIndices.bytes) + faceIndex*3;
        UInt32 index0 = indexBuffer[0];
        UInt32 index1 = indexBuffer[1];
        UInt32 index2 = indexBuffer[2];
        tin.CreateIndexedTriangle(var, index0, index1, index2);
    }
    
    for (NSUInteger vertexIndex = 0; vertexIndex < vertexCount; vertexIndex++) {
        delete(var[vertexIndex]);
    }
    free(var);
    progress.completedUnitCount = 3;

    tin.rebuildConnectivity();
    
    progress.completedUnitCount = 4;

    tin.fixConnectivity();
    
    progress.completedUnitCount = 5;

    tin.removeSmallestComponents();
    
    progress.completedUnitCount = 6;
    // Fill holes
    if (tin.boundaries()) {
        tin.fillSmallBoundaries(0, true);
    }
    progress.completedUnitCount = 7;

    tin.meshclean();
    
    progress.completedUnitCount = 8;
    
    Node *node = NULL;
    size_t resultPositionByteSize = sizeof(Float32)*tin.V.numels() * 3;
    NSData * resultPosition = [[NSData alloc] initWithBytesNoCopy:malloc(resultPositionByteSize) length:resultPositionByteSize freeWhenDone:YES];
    NSData * resultColors = nil;
    if (colorAttributes != nil) {
        size_t resultColorsByteSize = sizeof(Float32)*tin.V.numels() * 3;
        resultColors = [[NSData alloc] initWithBytesNoCopy:malloc(resultColorsByteSize) length:resultColorsByteSize freeWhenDone:YES];
    }
    node = NULL;
    NSUInteger index = 0;
    FOREACHNODE(tin.V, node) {
        Vertex *vertex = (Vertex *)node->data;
        ((Float32 *)resultPosition.bytes)[index*3] = vertex->x;
        ((Float32 *)resultPosition.bytes)[index*3 + 1] = vertex->y;
        ((Float32 *)resultPosition.bytes)[index*3 + 2] = vertex->z;
        
        if (resultColors != nil) {
            Color *color = vertex->color;
            ((Float32 *)resultColors.bytes)[index*3] = color ? color->r : 0;
            ((Float32 *)resultColors.bytes)[index*3 + 1] = color ? color->g : 0;
            ((Float32 *)resultColors.bytes)[index*3 + 2] = color ? color->b : 0;
        }
        //to find indices faster, we put the index of the vertex inside the x dimension
        vertex->x = index;
        index += 1;
    }
    progress.completedUnitCount = 9;

    MDLMesh * result = [[MDLMesh alloc] initWithBufferAllocator:nil];
    result.vertexCount = tin.V.numels();
    [result addAttributeWithName:@"positions" format:MDLVertexFormatFloat3 type:MDLVertexAttributePosition data:resultPosition stride:sizeof(Float32)*3];
    if (resultColors != nil) {
        [result addAttributeWithName:@"colors" format:MDLVertexFormatFloat3 type:MDLVertexAttributeColor data:resultColors stride:sizeof(Float32)*3];
    }

    size_t resultTriangleIndicesByteSize = sizeof(UInt32)*tin.T.numels() * 3;
    NSData * resultTrianglesIndices = [[NSData alloc] initWithBytesNoCopy:malloc(resultTriangleIndicesByteSize)
                                                                   length:resultTriangleIndicesByteSize freeWhenDone:YES];
    node = NULL;
    index = 0;
    FOREACHNODE(tin.T, node) {
        Triangle *triangle = (Triangle *)node->data;
        ((UInt32 *)resultTrianglesIndices.bytes)[index*3] = (UInt32)triangle->v1()->x;
        ((UInt32 *)resultTrianglesIndices.bytes)[index*3 + 1] = (UInt32)triangle->v2()->x;
        ((UInt32 *)resultTrianglesIndices.bytes)[index*3 + 2] = (UInt32)triangle->v3()->x;
        index += 1;
    }
    
    MDLMeshBufferData *resultTriangleIndicesBufferData = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeIndex data:resultTrianglesIndices];
    MDLSubmesh *triangleSubMesh = [[MDLSubmesh alloc] initWithIndexBuffer:resultTriangleIndicesBufferData indexCount:tin.T.numels() * 3
                                                                indexType:MDLIndexBitDepthUint32 geometryType:MDLGeometryTypeTriangles
                                                                 material:nil];
    [result.submeshes addObject:triangleSubMesh];
    [result addNormalsWithAttributeNamed:@"normal" creaseThreshold:0.5];

    progress.completedUnitCount = 10;
    
    return result;
}
@end
