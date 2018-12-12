/* file: decision_tree_classification_training_types.h */
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
//  Implementation of the Decision tree algorithm interface
//--
*/

#ifndef __DECISION_TREE_CLASSIFICATION_TRAINING_TYPES_H__
#define __DECISION_TREE_CLASSIFICATION_TRAINING_TYPES_H__

#include "algorithms/algorithm.h"
#include "data_management/data/data_serialize.h"
#include "algorithms/decision_tree/decision_tree_classification_model.h"
#include "algorithms/classifier/classifier_training_types.h"

namespace daal
{
namespace algorithms
{

/**
 * \brief Contains classes of the Decision tree algorithm
 */
namespace decision_tree
{

/**
 * \brief Contains classes of the Decision tree classification algorithm
 */
namespace classification
{

/**
 * @defgroup decision_tree_classification_training Training
 * \copydoc daal::algorithms::decision_tree::classification::training
 * @ingroup decision_tree_classification
 * @{
 */
/**
 * \brief Contains a class for Decision tree model-based training
 */
namespace training
{

/**
 * <a name="DAAL-ENUM-ALGORITHMS__DECISION_TREE__CLASSIFICATION__TRAINING__METHOD"></a>
 * \brief Computation methods for Decision tree model-based training
 */
enum Method
{
    defaultDense = 0 /*!< Default method */
};

/**
 * <a name="DAAL-ENUM-ALGORITHMS__DECISION_TREE__CLASSIFICATION__TRAINING__INPUTID"></a>
 * Available identifiers of the results in the training stage of Decision tree
 */
enum InputId
{
    dataForPruning      = algorithms::classifier::training::lastInputId + 1,  /*!< Pruning data set */
    labelsForPruning,                                                         /*!< Labels of the pruning data set */
    lastInputId = labelsForPruning
};

/**
 * \brief Contains version 1.0 of the Intel(R) Data Analytics Acceleration Library (Intel(R) DAAL) interface
 */
namespace interface1
{

/**
 * <a name="DAAL-CLASS-ALGORITHMS__CLASSIFIER__TRAINING__INPUT"></a>
 * \brief Base class for the input objects in the training stage of the classification algorithms
 */
class DAAL_EXPORT Input : public classifier::training::Input
{
public:
    Input();
    Input(const Input& other) : classifier::training::Input(other){}

    using classifier::training::Input::get;
    using classifier::training::Input::set;

    /**
     * Returns the input object in the training stage of the classification algorithm
     * \param[in] id   Identifier of the input object, \ref InputId
     * \return         Input object that corresponds to the given identifier
     */
    data_management::NumericTablePtr get(decision_tree::classification::training::InputId id) const;

    /**
     * Sets the input object in the training stage of the classification algorithm
     * \param[in] id    Identifier of the input object, \ref InputId
     * \param[in] value Pointer to the input object
     */
    void set(decision_tree::classification::training::InputId id, const data_management::NumericTablePtr & value);

    /**
     * Checks the correctness of the input object
     * \param[in] parameter Pointer to the structure of the algorithm parameters
     * \param[in] method    Computation method
     */
    services::Status check(const daal::algorithms::Parameter * parameter, int method) const DAAL_C11_OVERRIDE;

protected:
    services::Status checkImpl(const daal::algorithms::Parameter * parameter) const;
};

typedef services::SharedPtr<Input> InputPtr;
typedef services::SharedPtr<const Input> InputConstPtr;

/**
 * <a name="DAAL-CLASS-ALGORITHMS__DECISION_TREE__CLASSIFICATION__TRAINING__RESULT"></a>
 * \brief Provides methods to access the result obtained with the compute() method of Decision tree model-based training
 */
class DAAL_EXPORT Result : public classifier::training::Result
{
public:
    DECLARE_SERIALIZABLE_CAST(Result);
    Result();

    /**
     * Returns the result of Decision tree model-based training
     * \param[in] id    Identifier of the result
     * \return          Result that corresponds to the given identifier
     */
    ModelPtr get(classifier::training::ResultId id) const;

    /**
     * Allocates memory to store the result of Decision tree model-based training
     * \param[in] input Pointer to an object containing the input data
     * \param[in] parameter %Parameter of Decision tree model-based training
     * \param[in] method Computation method for the algorithm
     */
    template<typename algorithmFPType>
    DAAL_EXPORT services::Status allocate(const daal::algorithms::Input * input, const Parameter * parameter, int method);

protected:
    /** \private */
    template<typename Archive, bool onDeserialize>
    services::Status serialImpl(Archive * arch)
    {
        return classifier::training::Result::serialImpl<Archive, onDeserialize>(arch);
    }
};

typedef services::SharedPtr<Result> ResultPtr;
typedef services::SharedPtr<const Result> ResultConstPtr;

} // namespace interface1

using interface1::Input;
using interface1::InputPtr;
using interface1::InputConstPtr;
using interface1::Result;
using interface1::ResultPtr;
using interface1::ResultConstPtr;

} // namespace training
/** @} */
} // namespace classification
} // namespace decision_tree
} // namespace algorithms
} // namespace daal

#endif
