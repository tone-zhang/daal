/* file: explained_variance_input.cpp */
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

/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
#include "daal.h"
#include "pca/quality_metric/JExplainedVarianceInput.h"
#include "pca/quality_metric/JExplainedVarianceInputId.h"
#include "common_helpers.h"

USING_COMMON_NAMESPACES();
using namespace daal::algorithms::pca::quality_metric;
using namespace daal::algorithms::pca::quality_metric::explained_variance;

#define EigenValues com_intel_daal_algorithms_pca_quality_metric_ExplainedVarianceInputId_eigenValuesId

/*
* Class:     com_intel_daal_algorithms_pca_quality_metric_ExplainedVarianceInput
* Method:    cSetInputTable
* Signature: (JIJ)V
*/
JNIEXPORT void JNICALL Java_com_intel_daal_algorithms_pca_quality_1metric_ExplainedVarianceInput_cSetInputTable
(JNIEnv *, jobject, jlong resAddr, jint id, jlong ntAddr)
{
    if(id == EigenValues)
        jniInput<explained_variance::Input>::set<explained_variance::InputId, NumericTable>(resAddr, explained_variance::eigenvalues, ntAddr);
}

/*
* Class:     com_intel_daal_algorithms_pca_quality_metric_ExplainedVarianceInput
* Method:    cGetInputTable
* Signature: (JI)J
*/
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_pca_quality_1metric_ExplainedVarianceInput_cGetInputTable
(JNIEnv *, jobject, jlong inputAddr, jint id)
{
    if(id != EigenValues) return (jlong)0;

    return jniInput<explained_variance::Input>::get<explained_variance::InputId, NumericTable>(inputAddr, id);
}
