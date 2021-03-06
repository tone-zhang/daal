/* file: LeafNodeDescriptor.java */
/*******************************************************************************
* Copyright 2014-2018 Intel Corporation.
*
* This software and the related documents are Intel copyrighted  materials,  and
* your use of  them is  governed by the  express license  under which  they were
* provided to you (License).  Unless the License provides otherwise, you may not
* use, modify, copy, publish, distribute,  disclose or transmit this software or
* the related documents without Intel's prior written permission.
*
* This software and the related documents  are provided as  is,  with no express
* or implied  warranties,  other  than those  that are  expressly stated  in the
* License.
*******************************************************************************/

/**
 * @ingroup classification
 * @{
 */
package com.intel.daal.algorithms.tree_utils.classification;

import com.intel.daal.algorithms.tree_utils.NodeDescriptor;

/**
 * <a name="DAAL-CLASS-ALGORITHMS-TREE_UTILS-CLASSIFICATION__NODEDESCRIPTOR"></a>
 * @brief Struct containing description of leaf node in classification descision tree
 */
public final class LeafNodeDescriptor extends NodeDescriptor {
    public long label;

    public LeafNodeDescriptor(long level_, long label_, double impurity_, long nNodeSampleCount_)
    {
        super.level = level_;
        label = label_;
        super.impurity = impurity_;
        super.nNodeSampleCount = nNodeSampleCount_;
    }
}
/** @} */
