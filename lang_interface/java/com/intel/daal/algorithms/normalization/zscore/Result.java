/* file: Result.java */
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
 * @ingroup zscore
 * @{
 */
package com.intel.daal.algorithms.normalization.zscore;

import com.intel.daal.utils.*;
import com.intel.daal.algorithms.Precision;
import com.intel.daal.data_management.data.Factory;
import com.intel.daal.data_management.data.NumericTable;
import com.intel.daal.services.DaalContext;

/**
 * <a name="DAAL-CLASS-ALGORITHMS__NORMALIZATION__ZSCORE__RESULT"></a>
 * @brief Results obtained with the compute() method of the Z-score normalization algorithm in the batch processing mode
 */
public final class Result extends com.intel.daal.algorithms.Result {
    /** @private */
    static {
        LibUtils.loadLibrary();
    }

    /**
     * Constructs the result of Z-score normalization algorithm
     * @param context   Context to manage the result of Z-score normalization algorithm
     */
    public Result(DaalContext context) {
        super(context);
        this.cObject = cNewResult();
    }

    public Result(DaalContext context, long cObject) {
        super(context, cObject);
    }

    /**
     * Returns the result of Z-score normalization
     * @param  id   Identifier of the result
     * @return Result that corresponds to the given identifier
     */
    public NumericTable get(ResultId id) {
        int idValue = id.getValue();
        if (idValue != ResultId.normalizedData.getValue() &&
            idValue != ResultId.means.getValue() &&
            idValue != ResultId.variances.getValue()) {
            throw new IllegalArgumentException("id unsupported");
        }
        return (NumericTable)Factory.instance().createObject(getContext(), cGetResultNumericTable(cObject, id.getValue()));
    }

    /**
     * Sets the final result of the Z-score normalization algorithm
     * @param id   Identifier of the result
     * @param val  Result that corresponds to the given identifier
     */
    public void set(ResultId id, NumericTable val) {
        int idValue = id.getValue();
        if (idValue != ResultId.normalizedData.getValue() &&
            idValue != ResultId.means.getValue() &&
            idValue != ResultId.variances.getValue()) {
            throw new IllegalArgumentException("id unsupported");
        }
        cSetResultNumericTable(cObject, id.getValue(), val.getCObject());
    }

    private native long cNewResult();
    private native long cGetResultNumericTable(long cObject, int id);
    private native void cSetResultNumericTable(long cObject, int id, long cNumericTable);
}
/** @} */
