//
//  algUtils.cpp
//  MeshFix
//
//  Created by Antoine Palazzolo on 27/11/2020.
//

#include "tmesh.h"

namespace T_MESH
{


// Implements the cutting and stitching procedure to convert to manifold mesh //
// Assumes that singular edges to be cut and stitched are marked as BIT5.  //

bool Basic_TMesh::pinch(Edge *e1, bool with_common_vertex)
{
    List *ee = (List *)e1->info;
    if (ee == NULL) return false;
    Node *n = NULL;
    Edge *e2=NULL;
    List *ve;
    
    if (with_common_vertex)
    {
        e1->v1->e0 = e1; ve = e1->v1->VE();
        FOREACHVEEDGE(ve, e2, n) if (e2 != e1 && e2->isOnBoundary() && (*(e2->oppositeVertex(e1->v1))) == (*(e1->v2)) && e1->merge(e2)) break;
        delete ve;
        if (n == NULL)
        {
            e1->v2->e0 = e1; ve = e1->v2->VE();
            FOREACHVEEDGE(ve, e2, n) if (e2 != e1 && e2->isOnBoundary() && (*(e2->oppositeVertex(e1->v2))) == (*(e1->v1)) && e1->merge(e2)) break;
            delete ve;
        }
    }
    else //if (ee->numels()==2)
    {
        if (e1->t1 != NULL)
        {
            FOREACHVEEDGE(ee, e2, n) if (e2 != e1 && (((*(e2->v1)) == (*(e1->v1)) && e2->t2 != NULL) || ((*(e2->v1)) == (*(e1->v2)) && e2->t1 != NULL)) && e1->merge(e2)) break;
        }
        else
        {
            FOREACHVEEDGE(ee, e2, n) if (e2 != e1 && (((*(e2->v1)) == (*(e1->v1)) && e2->t1 != NULL) || ((*(e2->v1)) == (*(e1->v2)) && e2->t2 != NULL)) && e1->merge(e2)) break;
        }
    }
    if (n == NULL) return false;
    
    ee->removeNode(e1); ee->removeNode(e2); e1->info = e2->info = NULL;
    if (ee->numels() == 0) delete ee;
    
    Edge *e, *e_1 = NULL, *e_2 = NULL;
    ve = e1->v1->VE();
    for (n = ve->head(); n != NULL; n = n->next()) if ((e = (Edge *)n->data)->info != NULL) { e_1 = e; break; }
    for (n = ve->tail(); n != NULL; n = n->prev()) if ((e = (Edge *)n->data)->info != NULL)
    {
        if ((*(e->oppositeVertex(e1->v1))) != (*(e_1->oppositeVertex(e1->v1)))) e_1 = NULL;
        break;
    }
    delete ve;
    
    ve = e1->v2->VE();
    for (n = ve->head(); n != NULL; n = n->next()) if ((e = (Edge *)n->data)->info != NULL) { e_2 = e; break; }
    for (n = ve->tail(); n != NULL; n = n->prev()) if ((e = (Edge *)n->data)->info != NULL)
    {
        if ((*(e->oppositeVertex(e1->v2))) != (*(e_2->oppositeVertex(e1->v2)))) e_2 = NULL;
        break;
    }
    delete ve;
    
    if (e_1 != NULL) pinch(e_1, true);
    if (e_2 != NULL) pinch(e_2, true);
    
    return true;
}


Edge *Basic_TMesh::duplicateEdge(Edge *e1)
{
    if (e1->t1 == NULL || e1->t2 == NULL) return NULL;
    Edge *e2 = newEdge(e1); //e2->invert();
    E.appendHead(e2);
    e1->t2->replaceEdge(e1, e2);
    e2->t2 = e1->t2; e1->t2 = NULL;
    return e2;
}

int Basic_TMesh::cutAndStitch()
{
    Edge *e1, *e2;
    Node *n;
    List singular_edges;
    
    FOREACHEDGE(e1, n) if (IS_BIT(e1, 5) && ((e2 = duplicateEdge(e1)) != NULL)) MARK_BIT(e2, 5);
    
    FOREACHEDGE(e1, n) if (IS_BIT(e1, 5))
    {
        singular_edges.appendHead(e1);
        UNMARK_BIT(e1, 5);
    }
    
    forceNormalConsistence();
    duplicateNonManifoldVertices();
    
    singular_edges.sort(&lexEdgeCompare);
    FOREACHEDGE(e1, n) e1->info = NULL;
    e2 = NULL;
    FOREACHVEEDGE((&singular_edges), e1, n)
    {
        if (e2 == NULL || lexEdgeCompare(e1, e2) != 0) { e1->info = new List(); e2 = e1; }
        ((List *)e2->info)->appendTail(e1);
        e1->info = e2->info;
    }
    // Now each edge is either 'regular' or has the info field pointing to a list of coincident boundary edges
    
    // First, pinch bounded chains of singular edges starting from one endpoint
    FOREACHVEEDGE((&singular_edges), e1, n) if (e1->isLinked()) pinch(e1, true);
    
    // Then, pinch the remaining unbounded chains starting from any of the edges
    FOREACHVEEDGE((&singular_edges), e1, n) if (e1->isLinked()) pinch(e1, false);
    
    removeUnlinkedElements();
    
    d_boundaries = d_handles = d_shells = 1;
    
    return singular_edges.numels();
}


//int Basic_TMesh::cutAndStitch()
//{
//    Edge *e1, *e2;
//    Node *n;
//    List cut;
//    int i;
//
//    FOREACHEDGE(e1, n) if (IS_BIT(e1, 5))
//    {
//        if (e1->t1 != NULL && e1->t2 != NULL)
//        {
//            e2 = newEdge(e1);
//            E.appendHead(e2);
//            e1->t2->replaceEdge(e1, e2);
//            e2->t2 = e1->t2; e1->t2 = NULL;
//        }
//        cut.appendHead(e1);
//        UNMARK_BIT(e1, 5);
//    }
//
//    do
//    {
//        i = 0;
//        FOREACHVEEDGE((&cut), e1, n) if (e1->v1 != NULL) i += e1->stitch();
//    } while (i);
//
//    removeEdges();
//
//    d_boundaries = d_handles = d_shells = 1;
//
//    return cut.numels();
//}

// This method should be called after a Save to ascii file to ensure
// coherence between in-memory data and saved data.

void Basic_TMesh::coordBackApproximation()
{
    Node *n;
    Vertex *v;
    char floatver[32];
    float x;
    
    FOREACHVERTEX(v, n)
    {
        sprintf(floatver, "%f", TMESH_TO_FLOAT(v->x)); sscanf(floatver, "%f", &x); v->x = x;
        sprintf(floatver, "%f", TMESH_TO_FLOAT(v->y)); sscanf(floatver, "%f", &x); v->y = x;
        sprintf(floatver, "%f", TMESH_TO_FLOAT(v->z)); sscanf(floatver, "%f", &x); v->z = x;
    }
}

Triangle * Basic_TMesh::CreateIndexedTriangle(ExtVertex **var, int i1, int i2, int i3)
{
    return CreateTriangleFromVertices(var[i1], var[i2], var[i3]);
}

Triangle * Basic_TMesh::CreateTriangleFromVertices(ExtVertex *vari1, ExtVertex *vari2, ExtVertex *vari3)
{
    Edge *e1, *e2, *e3;
    Triangle *t = NULL;
    
    e1 = CreateEdge(vari1,vari2); if (e1->t1 != NULL && e1->t2 != NULL) MARK_BIT(e1,5);
    e2 = CreateEdge(vari2,vari3); if (e2->t1 != NULL && e2->t2 != NULL) MARK_BIT(e2,5);
    e3 = CreateEdge(vari3,vari1); if (e3->t1 != NULL && e3->t2 != NULL) MARK_BIT(e3,5);
    if (IS_BIT(e1,5)) {e1 = CreateEdge(vari1,vari2,0); MARK_BIT(e1,5);}
    if (IS_BIT(e2,5)) {e2 = CreateEdge(vari2,vari3,0); MARK_BIT(e2,5);}
    if (IS_BIT(e3,5)) {e3 = CreateEdge(vari3,vari1,0); MARK_BIT(e3,5);}
    
    if ((t=CreateUnorientedTriangle(e1,e2,e3)) == NULL)
    {
        if (e3->t1 == NULL && e3->t2 == NULL)
        {
            E.freeNode(e3);
            vari3->VE.removeNode(e3); vari1->VE.removeNode(e3);
            if (vari3->v->e0 == e3) vari3->v->e0 = NULL;
            if (vari1->v->e0 == e3) vari1->v->e0 = NULL;
        }
        if (e2->t1 == NULL && e2->t2 == NULL)
        {
            E.freeNode(e2);
            vari2->VE.removeNode(e2); vari3->VE.removeNode(e2);
            if (vari2->v->e0 == e2) vari2->v->e0 = NULL;
            if (vari3->v->e0 == e2) vari3->v->e0 = NULL;
        }
        if (e1->t1 == NULL && e1->t2 == NULL)
        {
            E.freeNode(e1);
            vari1->VE.removeNode(e1); vari2->VE.removeNode(e1);
            if (vari1->v->e0 == e1) vari1->v->e0 = NULL;
            if (vari2->v->e0 == e1) vari2->v->e0 = NULL;
        }
    }
    
    return t;
}

} //namespace T_MESH
