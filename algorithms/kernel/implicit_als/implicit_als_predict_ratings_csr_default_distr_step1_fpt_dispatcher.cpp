/* file: implicit_als_predict_ratings_csr_default_distr_step1_fpt_dispatcher.cpp */
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
//  Implementation of implicit ALS distributed prediction algorithm container.
//--
*/

#include "kernel.h"
#include "implicit_als_predict_ratings_distributed.h"

namespace daal
{
namespace algorithms
{
namespace interface1
{
__DAAL_INSTANTIATE_DISPATCH_CONTAINER(implicit_als::prediction::ratings::DistributedContainer, distributed, step1Local, \
                                      DAAL_FPTYPE, implicit_als::prediction::ratings::defaultDense)
}
}
}
