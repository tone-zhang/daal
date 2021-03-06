/* file: result.cpp */
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

#include <jni.h>
#include "neural_networks/initializers/JResult.h"
#include "neural_networks/initializers/JResultId.h"

#include "daal.h"

#include "common_helpers.h"

#define valueId com_intel_daal_algorithms_neural_networks_initializers_ResultId_valueId

USING_COMMON_NAMESPACES()
using namespace daal::algorithms::neural_networks;

/*
 * Class:     com_intel_daal_algorithms_neural_networks_initializers_Result
 * Method:    cGetValue
 * Signature: (JI)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_neural_1networks_initializers_Result_cGetValue
  (JNIEnv *env, jobject thisObj, jlong resAddr, jint id)
{
    return jniArgument<initializers::Result>::get<initializers::ResultId, Tensor>(resAddr, id);
}

/*
 * Class:     com_intel_daal_algorithms_neural_networks_initializers_Result
 * Method:    cSetValue
 * Signature: (JIJ)V
 */
JNIEXPORT void JNICALL Java_com_intel_daal_algorithms_neural_1networks_initializers_Result_cSetValue
  (JNIEnv *env, jobject thisObj, jlong resAddr, jint id, jlong tensorAddr)
{
    if (id == valueId)
    {
        jniArgument<initializers::Result>::set<initializers::ResultId, Tensor>(resAddr, id, tensorAddr);
    }
}
