/* file: StochasticPooling2dLayerDataId.java */
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
 * @ingroup stochastic_pooling2d
 * @{
 */
package com.intel.daal.algorithms.neural_networks.layers.stochastic_pooling2d;

import com.intel.daal.utils.*;
/**
 * <a name="DAAL-CLASS-ALGORITHMS__NEURAL_NETWORKS__LAYERS__STOCHASTIC_POOLING2D__STOCHASTICPOOLING2DLAYERDATAID"></a>
 * \brief Identifiers of input objects for the backward two-dimensional stochastic pooling layer and
 *        results for the forward two-dimensional stochastic pooling layer
 */
public final class StochasticPooling2dLayerDataId {
    /** @private */
    static {
        LibUtils.loadLibrary();
    }

    private int _value;

    /**
     * Constructs the input object identifier using the provided value
     * @param value     Value corresponding to the input object identifier
     */
    public StochasticPooling2dLayerDataId(int value) {
        _value = value;
    }

    /**
     * Returns the value corresponding to the input object identifier
     * @return Value corresponding to the input object identifier
     */
    public int getValue() {
        return _value;
    }

    private static final int auxSelectedIndicesId = 0;

    public static final StochasticPooling2dLayerDataId auxSelectedIndices = new StochasticPooling2dLayerDataId(
        auxSelectedIndicesId);    /*!< p-dimensional tensor that stores the positions of stochastic elements */
}
/** @} */
