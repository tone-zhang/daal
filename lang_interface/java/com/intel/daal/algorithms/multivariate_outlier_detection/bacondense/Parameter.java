/* file: Parameter.java */
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
 * @ingroup multivariate_outlier_detection_bacondense
 * @{
 */
package com.intel.daal.algorithms.multivariate_outlier_detection.bacondense;

import com.intel.daal.utils.*;
import com.intel.daal.services.DaalContext;

/**
 * <a name="DAAL-CLASS-ALGORITHMS__MULTIVARIATE_OUTLIER_DETECTION__BACONDENSE__PARAMETER"></a>
 * @brief Parameters of the multivariate outlier detection compute() method used with the baconDense method \DAAL_DEPRECATED_USE{com.intel.daal.algorithms.bacon_outlier_detection.Parameter}
 */
@Deprecated
public class Parameter extends com.intel.daal.algorithms.Parameter {
    /** @private */
    static {
        LibUtils.loadLibrary();
    }

    public Parameter(DaalContext context, long cParameter) {
        super(context);
        this.cObject = cParameter;
    }

    /**
     * Sets initialization method for the BACON multivariate outlier detection algorithm
     * @param method Initialization method
     */
    public void setInitializationMethod(InitializationMethod method) {}

    /**
     * Returns initialization method of the BACON multivariate outlier detection algorithm
     * @return Initialization method
     */
    public InitializationMethod getInitializationMethod() {
        return InitializationMethod.baconMedian;
    }

    /**
     * Sets alpha parameter of the BACON method.
     * alpha is a one-tailed probability that defines the \f$(1 - \alpha)\f$ quantile
     * of the \f$\chi^2\f$ distribution with \f$p\f$ degrees of freedom.
     * Recommended value: \f$\alpha / n\f$, where n is the number of observations.
     * @param alpha Value of the parameter alpha
     */
    public void setAlpha(double alpha) {}

    /**
     * Returns the parameter alpha of the BACON method.
     * @return Parameter alpha of the BACON method.
     */
    public double getAlpha() {return 0.0;}

    /**
     * Sets the threshold for the stopping criterion of the algorithms.
     * Stopping criterion: the algorithm is terminated if the size of the basic subset
     * is changed by less than the threshold.
     * @param threshold     Threshold for the stopping criterion of the algorithm
     */
    public void setToleranceToConverge(double threshold) {}

    /**
     * Sets the threshold for the stopping criterion of the algorithms.
     * @return Threshold for the stopping criterion of the algorithm
     */
    public double getToleranceToConverge() {
        return 0.0;
    }
}
/** @} */
