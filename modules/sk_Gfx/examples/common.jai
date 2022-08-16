//
// Common staff used in the examples
//

// projections
//
// left_handed = true (LHS)
//   Y+
//    |     / Z+ (forward)
//    |    /    
//    |   /        
//    |  /     
//    | /       
//-------------------X+
//    |

// left_handed = false (RHS)
//   Y+
//    |     / Z- (forward)
//    |    /    
//    |   /        
//    |  /     
//    | /       
//-------------------X+
//    |

make_orthographic_projection :: (left:float, right:float, bottom:float, top:float, near:float, far:float, $left_handed:bool, $depth01:bool) -> Matrix4 {
    m: Matrix4;
    // if left_handed is true, z+ is forward (d3d style), if false z- is forward (gl style)
    #if left_handed {
        s := 1.0;
    } else {
        s := -1.0;
    }
    m._11 = 2.0 / (right - left);
    m._14 = - (right + left) / (right - left);
    m._22 = 2.0 / (top - bottom);
    m._24 = - (top + bottom) / (top - bottom);
    m._33 = s * 2.0 / (far - near);
    m._34 = - (far + near) / (far - near);
    m._44 = 1.0;

    #if depth01 {
        // To map -1,1 depth range to 0,1 we transform z as follows: z' = z * 0.5 + 0.5
        m._33 = m._33 * 0.5 + m._43 * 0.5;
        m._34 = m._34 * 0.5 + m._44 * 0.5;
    }
    return m;
}

// fovy in (in degrees).
// aspect -> aspect ratio of horizontal/vertical or width/height.
make_perspective_projection :: (fovy:float, aspect:float, near:float, far:float, $left_handed:bool, $depth01:bool) -> Matrix4 {
    m: Matrix4;
    to_rad :: PI/180.0;
    tan_theta := tan(fovy * to_rad * 0.5);
    cot_theta := 1 / tan_theta;
    denom     := 1 / (far - near);
    
    #if left_handed {
        s := 1.0;
    } else {
        s := -1.0;
    }

    m._11 = cot_theta / aspect;
    m._22 = cot_theta;
    m._33 = s * (far + near) * denom;
    m._43 = s;
    m._34 = -2 * far * near * denom;
    m._44 = 0;

    #if depth01 {
        // To map -1,1 depth range to 0,1 we transform z as follows: z' = z * 0.5 + 0.5
        m._33 = m._33 * 0.5 + m._43 * 0.5;
        m._34 = m._34 * 0.5 + m._44 * 0.5;
    }

    return m;
}

make_look_at :: (viewpoint: Vector3, look_at: Vector3, reference_up_vector: Vector3, $left_handed:bool) -> Matrix4 {
    #if left_handed {
    forward := look_at - viewpoint; // z+ is forward 
    } else {
    forward = viewpoint -look_at;   // z- is forward
    }
    normalize_or_z_axis(*forward);
    right := cross_product(reference_up_vector, forward);
    normalize_or_z_axis(*right);
    up := cross_product(forward, right);
    normalize_or_z_axis(*up);  
    m := make_matrix_from_rows(right, up, forward);
    translate(*m, -viewpoint);
    return m;
}