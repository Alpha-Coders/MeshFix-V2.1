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

+ (MDLMesh * _Nonnull)fixMesh:(MDLMesh * _Nonnull)mesh addEdgeSubMesh:(BOOL)addEdgeSubMesh {
    
    NSUInteger submeshIndex = [[mesh submeshes] indexOfObjectPassingTest:^BOOL(MDLSubmesh * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return obj.geometryType == MDLGeometryTypeTriangles;
    }];
    if (submeshIndex == NSNotFound) { @throw @"triangle submesh not found"; }

    MDLSubmesh *submesh = mesh.submeshes[submeshIndex];
    MDLMeshBufferMap * meshFaceIndices = [[submesh indexBufferAsIndexType:MDLIndexBitDepthUInt32] map];
    MDLVertexAttributeData *positionAttributes = [mesh vertexAttributeDataForAttributeNamed:MDLVertexAttributePosition asFormat:MDLVertexFormatFloat3];
    
    Basic_TMesh tin;
    
    NSUInteger maxVertexIndex = 0;
    NSUInteger faceCount = submesh.indexCount/3;

    for (NSUInteger faceIndex = 0; faceIndex < faceCount; faceIndex++) {
        UInt32 * indexBuffer = ((UInt32 *)meshFaceIndices.bytes) + faceIndex*3;
        maxVertexIndex = MAX(maxVertexIndex, indexBuffer[0]);
        maxVertexIndex = MAX(maxVertexIndex, indexBuffer[1]);
        maxVertexIndex = MAX(maxVertexIndex, indexBuffer[2]);
    }
    NSUInteger verticesCount = maxVertexIndex + 1;
    ExtVertex **var = (ExtVertex **)malloc(sizeof(ExtVertex *)*verticesCount);

    for (NSUInteger vertexIndex = 0; vertexIndex < verticesCount; vertexIndex++) {
        Float32 * vertexBuffer = (Float32 *)((UInt8 *)positionAttributes.dataStart + vertexIndex * positionAttributes.stride);
        Vertex *v = tin.newVertex(vertexBuffer[0], vertexBuffer[1], vertexBuffer[2]);
        tin.V.appendTail(v);
        var[vertexIndex] = new ExtVertex(v);
    }
    for (NSUInteger faceIndex = 0; faceIndex < faceCount; faceIndex++) {
        UInt32 * indexBuffer = ((UInt32 *)meshFaceIndices.bytes) + faceIndex*3;
        UInt32 index0 = indexBuffer[0];
        UInt32 index1 = indexBuffer[1];
        UInt32 index2 = indexBuffer[2];
        tin.CreateIndexedTriangle(var, index0, index1, index2);
    }
    
    for (NSUInteger vertexIndex = 0; vertexIndex < verticesCount; vertexIndex++) {
        delete(var[vertexIndex]);
    }
    free(var);
    
    tin.fixConnectivity();
    
    // Keep only the largest component (i.e. with most triangles)
    tin.removeSmallestComponents();
    
    // Fill holes
    if (tin.boundaries()) {
        tin.fillSmallBoundaries(0, true);
    }
    tin.meshclean();
    
    size_t resultVerticesByteSize = sizeof(Float32)*tin.V.numels() * 3;
    NSData * resultVertices = [[NSData alloc] initWithBytesNoCopy:malloc(resultVerticesByteSize) length:resultVerticesByteSize freeWhenDone:YES];

    Node *node = NULL;
    NSUInteger index = 0;
    FOREACHNODE(tin.V, node) {
        ((Float32 *)resultVertices.bytes)[index] = ((Vertex *)node->data)->x;
        ((Float32 *)resultVertices.bytes)[index + 1] = ((Vertex *)node->data)->y;
        ((Float32 *)resultVertices.bytes)[index + 2] = ((Vertex *)node->data)->z;
        index += 3;
    }
    MDLMesh * result = [[MDLMesh alloc] initWithBufferAllocator:nil];
    result.vertexCount = tin.V.numels();
    [result addAttributeWithName:@"positions" format:MDLVertexFormatFloat3 type:MDLVertexAttributePosition data:resultVertices stride:sizeof(Float32)*3];

    //to find indices faster, we put the index of the vertex inside the x dimension
    index = 0;
    FOREACHNODE(tin.V, node) {
        ((Vertex *)node->data)->x = index;
        index += 1;
    }
    
    size_t resultTriangleIndicesByteSize = sizeof(UInt32)*tin.T.numels() * 3;
    NSData * resultTrianglesIndices = [[NSData alloc] initWithBytesNoCopy:malloc(resultTriangleIndicesByteSize)
                                                                   length:resultTriangleIndicesByteSize freeWhenDone:YES];
    node = NULL;
    index = 0;
    FOREACHNODE(tin.T, node) {
        Triangle *triangle = (Triangle *)node->data;
        ((UInt32 *)resultTrianglesIndices.bytes)[index] = (UInt32)triangle->v1()->x;
        ((UInt32 *)resultTrianglesIndices.bytes)[index + 1] = (UInt32)triangle->v2()->x;
        ((UInt32 *)resultTrianglesIndices.bytes)[index + 2] = (UInt32)triangle->v3()->x;
        index += 3;
    }
    
    MDLMeshBufferData *resultTriangleIndicesBufferData = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeIndex data:resultTrianglesIndices];
    MDLSubmesh *triangleSubMesh = [[MDLSubmesh alloc] initWithIndexBuffer:resultTriangleIndicesBufferData indexCount:tin.T.numels() * 3
                                                                indexType:MDLIndexBitDepthUint32 geometryType:MDLGeometryTypeTriangles
                                                                 material:nil];

    
    [result.submeshes addObject:triangleSubMesh];
    [result addNormalsWithAttributeNamed:@"normal" creaseThreshold:0.5];

    if (addEdgeSubMesh) {
        size_t resultEdgesIndicesByteSize = sizeof(UInt32)*tin.E.numels() * 2;
        NSData * resultEdgesIndices = [[NSData alloc] initWithBytesNoCopy:malloc(resultEdgesIndicesByteSize)
                                                                   length:resultEdgesIndicesByteSize freeWhenDone:YES];
        node = NULL;
        index = 0;
        FOREACHNODE(tin.E, node) {
            Edge *edge = (Edge *)node->data;
            ((UInt32 *)resultEdgesIndices.bytes)[index] = (UInt32)edge->v1->x;
            ((UInt32 *)resultEdgesIndices.bytes)[index + 1] = (UInt32)edge->v2->x;
            index += 3;
        }
        MDLMeshBufferData *resultEdgeIndicesBufferData = [[MDLMeshBufferData alloc] initWithType:MDLMeshBufferTypeIndex data:resultEdgesIndices];
        MDLSubmesh *edgeSubMesh = [[MDLSubmesh alloc] initWithIndexBuffer:resultEdgeIndicesBufferData indexCount:tin.E.numels() * 2
                                                                indexType:MDLIndexBitDepthUint32 geometryType:MDLGeometryTypeLines
                                                                 material:nil];
        [result.submeshes addObject:edgeSubMesh];
    }

    return result;
}
@end
