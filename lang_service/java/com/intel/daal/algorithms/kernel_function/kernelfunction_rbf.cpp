/* file: kernelfunction_rbf.cpp */
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
#include "rbf/JBatch.h"
#include "rbf/JResult.h"
#include "rbf/JMethod.h"
#include "daal.h"

#include "common_helpers.h"

USING_COMMON_NAMESPACES();
using namespace daal::algorithms::kernel_function::rbf;

#define DefaultDense com_intel_daal_algorithms_kernel_function_rbf_Method_defaultDenseValue
#define FastCSR      com_intel_daal_algorithms_kernel_function_rbf_Method_fastCSRValue

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch
 * Method:    cInit
 * Signature: (II)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cInit
(JNIEnv *env, jobject thisObj, jint prec, jint method)
{
    return jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::newObj(prec, method);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_linear_Batch
 * Method:    cGetParameter
 * Signature: (II)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cGetParameter
(JNIEnv *env, jobject thisObj, jlong algAddr, jint prec, jint method)
{
    return jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::getParameter(prec, method, algAddr);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch
 * Method:    cSetResult
 * Signature:(JIIJ)I
 */
JNIEXPORT void JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cSetResult
(JNIEnv *env, jobject obj, jlong algAddr, jint prec, jint method, jlong resultAddr)
{
    jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::setResult<kernel_function::Result>(prec, method, algAddr, resultAddr);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch
 * Method:    cGetResult
 * Signature:(JII)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cGetResult
(JNIEnv *env, jobject obj, jlong algAddr, jint prec, jint method)
{
    return jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::getResult(prec, method, algAddr);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch
 * Method:    cGetInput
 * Signature:(JII)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cGetInput
(JNIEnv *env, jobject obj, jlong algAddr, jint prec, jint method)
{
    return jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::getInput(prec, method, algAddr);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch
 * Method:    cClone
 * Signature: (JII)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Batch_cClone
(JNIEnv *env, jobject thisObj, jlong algAddr, jint prec, jint method)
{
    return jniBatch<kernel_function::rbf::Method, Batch, defaultDense, fastCSR>::getClone(prec, method, algAddr);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch_Result
 * Method:    cGetResult
 * Signature:()J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Result_cNewResult
(JNIEnv *env, jobject obj)
{
    return jniArgument<kernel_function::Result>::newObj();
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch_Result
 * Method:    cGetResultTable
 * Signature:(J)J
 */
JNIEXPORT jlong JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Result_cGetResultTable
(JNIEnv *env, jobject obj, jlong resAddr, jint id)
{
    return jniArgument<kernel_function::Result>::get<kernel_function::ResultId, NumericTable>(resAddr, id);
}

/*
 * Class:     com_intel_daal_algorithms_kernel_function_rbf_Batch_Result
 * Method:    cSetResultTable
 * Signature:(JJ)I
 */
JNIEXPORT void JNICALL Java_com_intel_daal_algorithms_kernel_1function_rbf_Result_cSetResultTable
(JNIEnv *env, jobject obj, jlong resAddr, jint id, jlong ntAddr)
{
    jniArgument<kernel_function::Result>::set<kernel_function::ResultId, NumericTable>(resAddr, id, ntAddr);
}
