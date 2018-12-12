/* file: OnlinePartialResult.java */
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
 * @ingroup qr_online
 * @{
 */
package com.intel.daal.algorithms.qr;

import com.intel.daal.utils.*;
import com.intel.daal.algorithms.ComputeMode;
import com.intel.daal.algorithms.ComputeStep;
import com.intel.daal.algorithms.Precision;
import com.intel.daal.data_management.data.DataCollection;
import com.intel.daal.services.DaalContext;

/**
 * <a name="DAAL-CLASS-ALGORITHMS__QR__ONLINEPARTIALRESULT"></a>
 * @brief Provides methods to access partial results obtained with the compute() method of the QR decomposition algorithm in the online
 * processing mode
 */
public class OnlinePartialResult extends com.intel.daal.algorithms.PartialResult {
    /** @private */
    static {
        LibUtils.loadLibrary();
    }

    public OnlinePartialResult(DaalContext context, long cObject) {
        super(context, cObject);
    }

    /**
     * Returns partial result of the QR decomposition algorithm
     * @param id    Identifier of partial result
     * @return      Partial result that corresponds to the given identifier
     */
    public DataCollection get(PartialResultId id) {
        if (id == PartialResultId.outputOfStep1ForStep3) {
            return new DataCollection(getContext(),
                    cGetDataCollection(getCObject(), PartialResultId.outputOfStep1ForStep3.getValue()));
        } else if (id == PartialResultId.outputOfStep1ForStep2) {
            return new DataCollection(getContext(),
                    cGetDataCollection(getCObject(), PartialResultId.outputOfStep1ForStep2.getValue()));
        } else {
            throw new IllegalArgumentException("id unsupported");
        }
    }

    //private DataCollection Q;
    //private DataCollection R;
    private native long cGetDataCollection(long presAddr, int id);
}
/** @} */
