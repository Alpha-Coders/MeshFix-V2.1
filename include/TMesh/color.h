//
//  color.h
//  MeshFix
//
//  Created by Antoine Palazzolo on 27/10/2020.
//

#ifndef color_h
#define color_h

namespace T_MESH {
struct Color {
    public :
    float r,g,b;
    Color(const float& r, const float& g, const float& b) {this->r = r; this->g = g; this->b = b;}
};
}
#endif /* color_h */
