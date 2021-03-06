/* file: multinomial_naive_bayes_quality_metric_set_types.h */
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

/*
//++
//  Interface for the Naive Bayes algorithm quality metrics
//--
*/

#ifndef __MULTINOMIAL_NAIVE_BAYES_QUALITY_METRIC_SET_TYPES_H__
#define __MULTINOMIAL_NAIVE_BAYES_QUALITY_METRIC_SET_TYPES_H__

#include "services/daal_shared_ptr.h"
#include "algorithms/algorithm_quality_metric_set_types.h"
#include "algorithms/classifier/multiclass_confusion_matrix_types.h"

namespace daal
{
namespace algorithms
{
namespace multinomial_naive_bayes
{
/**
 * @defgroup multinomial_naive_bayes_quality_metric_set Quality Metrics
 * \copydoc daal::algorithms::multinomial_naive_bayes::quality_metric_set
 * @ingroup multinomial_naive_bayes
 * @{
 */
namespace quality_metric_set
{
/**
 * <a name="DAAL-ENUM-ALGORITHMS__MULTINOMIAL_NAIVE_BAYES__QUALITY_METRIC_SET__QUALITYMETRICID"></a>
 * Available identifiers of the quality metrics available for the model trained with the Naive Bayes algorithm
 */
enum QualityMetricId
{
    confusionMatrix,     /*!< Confusion matrix */
    lastQualityMetricId = confusionMatrix
};

/**
 * \brief Contains version 1.0 of the Intel(R) Data Analytics Acceleration Library (Intel(R) DAAL) interface.
 */
namespace interface1
{
/**
* <a name="DAAL-STRUCT-ALGORITHMS__MULTINOMIAL_NAIVE_BAYES__QUALITY_METRIC_SET__PARAMETER"></a>
* \brief Parameters for the Naive Bayes compute() method
*
* \snippet naive_bayes/multinomial_naive_bayes_quality_metric_set_types.h Parameter source code
*/
/* [Parameter source code] */
struct DAAL_EXPORT Parameter : public daal::algorithms::Parameter
{
    Parameter(size_t nClasses = 2);
    virtual ~Parameter() {}

    size_t nClasses;        /*!< Number of classes */
};
/* [Parameter source code] */

/**
 * <a name="DAAL-CLASS-ALGORITHMS__MULTINOMIAL_NAIVE_BAYES__QUALITY_METRIC_SET__RESULTCOLLECTION"></a>
 * \brief Class that implements functionality of the collection of result objects of the quality metrics algorithm
 *        specialized for using with the Naive Bayes training algorithm
 */
class DAAL_EXPORT ResultCollection : public algorithms::quality_metric_set::ResultCollection
{
public:
    ResultCollection() {}
    virtual ~ResultCollection() {}

    /**
     * Returns the result of the quality metrics algorithm
     * \param[in] id   Identifier of the result
     * \return         Result that corresponds to the given identifier
     */
    classifier::quality_metric::multiclass_confusion_matrix::ResultPtr getResult(QualityMetricId id) const;
};
typedef services::SharedPtr<ResultCollection> ResultCollectionPtr;

/**
 * <a name="DAAL-CLASS-ALGORITHMS__MULTINOMIAL_NAIVE_BAYES__QUALITY_METRIC_SET__INPUTDATACOLLECTION"></a>
 * \brief Class that implements functionality of the collection of input objects for the quality metrics algorithm
 *        specialized for using with the Naive Bayes training algorithm
 */
class DAAL_EXPORT InputDataCollection : public algorithms::quality_metric_set::InputDataCollection
{
public:
    InputDataCollection() {}
    virtual ~InputDataCollection() {}

    /**
     * Returns the input object of the quality metrics algorithm
     * \param[in] id    Identifier of the input object
     * \return          %Input object that corresponds to the given identifier
     */
    classifier::quality_metric::multiclass_confusion_matrix::InputPtr getInput(QualityMetricId id) const;
};
typedef services::SharedPtr<InputDataCollection> InputDataCollectionPtr;
}
using interface1::Parameter;
using interface1::ResultCollection;
using interface1::ResultCollectionPtr;
using interface1::InputDataCollection;
using interface1::InputDataCollectionPtr;

}
/** @} */
}
}
}

#endif // __MULTINOMIAL_NAIVE_BAYES_QUALITY_METRIC_SET_TYPES_H__
