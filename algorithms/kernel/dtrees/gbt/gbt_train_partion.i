/* file: gbt_train_partion.i */
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
//  Implementation of partitions for gradient boosted trees training
//  (defaultDense) method.
//--
*/

#ifndef __GBT_TRAIN_PARTION_I__
#define __GBT_TRAIN_PARTION_I__

#include "gbt_train_aux.i"
#include "dtrees_model_impl.h"
#include "dtrees_train_data_helper.i"
#include "dtrees_predict_dense_default_impl.i"

namespace daal
{
namespace algorithms
{
namespace gbt
{
namespace training
{
namespace internal
{

template<typename algorithmFPType, typename IndexType, CpuType cpu>
class PartitionTaskBase: public GbtTask
{
public:
    using SharedDataType = SharedDataForTree<algorithmFPType, IndexType, cpu>;
    using NodeInfoType   = SplitJob<algorithmFPType,cpu>;
    using ImpurityType   = ImpurityData<algorithmFPType, cpu>;
    using SplitDataType  = SplitData<algorithmFPType, ImpurityType>;
    using IndexTypeVector = TVector<IndexType, cpu>;

    PartitionTaskBase(size_t iFeature, DAAL_INT idxFeatureValueBestSplit, SharedDataType& sharedData, const NodeInfoType& nodeInfo, SplitDataType& bestSplit):
        _iFeature(iFeature), _idxFeatureValueBestSplit(idxFeatureValueBestSplit),  _sharedData(sharedData), _nodeInfo(nodeInfo), _bestSplit(bestSplit)
    {
    }

    virtual GbtTask* execute()
    {
        IndexType* bestSplitIdx = _sharedData.bestSplitIdxBuf + _nodeInfo.iStart;
        IndexType* aIdx = _sharedData.aIdx + _nodeInfo.iStart;

        bool bCopy = true;
        if(_idxFeatureValueBestSplit >= 0)
        {
            finalizeBestSplit(_nodeInfo.n, _nodeInfo.iStart);
        }
        else if(_bestSplit.featureUnordered)
        {
            if(_bestSplit.iStart)
            {
                DAAL_ASSERT(_bestSplit.iStart + _bestSplit.nLeft <= _nodeInfo.n);
                services::internal::tmemcpy<IndexType, cpu>(aIdx, bestSplitIdx + _bestSplit.iStart, _bestSplit.nLeft);
                aIdx += _bestSplit.nLeft;
                services::internal::tmemcpy<IndexType, cpu>(aIdx, bestSplitIdx, _bestSplit.iStart);
                aIdx += _bestSplit.iStart;
                bestSplitIdx += _bestSplit.iStart + _bestSplit.nLeft;
                if(_nodeInfo.n > (_bestSplit.iStart + _bestSplit.nLeft))
                    services::internal::tmemcpy<IndexType, cpu>(aIdx, bestSplitIdx, _nodeInfo.n - _bestSplit.iStart - _bestSplit.nLeft);
                bCopy = false;
            }
        }
        if(bCopy && _sharedData.ctx.par().memorySavingMode)
            services::internal::tmemcpy<IndexType, cpu>(aIdx, bestSplitIdx, _nodeInfo.n);

        return nullptr;
    }

protected:
    virtual void finalizeBestSplit(size_t n, size_t iStart) = 0;

    size_t _iFeature;
    DAAL_INT _idxFeatureValueBestSplit;
    SharedDataType& _sharedData;
    const NodeInfoType& _nodeInfo;
    SplitDataType& _bestSplit;
};

template<typename algorithmFPType, typename IndexType, CpuType cpu>
class PartitionMemSafetyTask: public PartitionTaskBase<algorithmFPType, IndexType, cpu>
{
public:
    using super = PartitionTaskBase<algorithmFPType, IndexType, cpu>;
    using SharedDataType = typename super::SharedDataType;
    using NodeInfoType   = typename super::NodeInfoType;
    using SplitDataType  = typename super::SplitDataType;

    PartitionMemSafetyTask(size_t iFeature, DAAL_INT idxFeatureValueBestSplit, SharedDataType& sharedData, const NodeInfoType& nodeInfo, SplitDataType& bestSplit):
            super(iFeature, idxFeatureValueBestSplit, sharedData, nodeInfo, bestSplit)
    {
    }

    virtual void finalizeBestSplit(size_t n, size_t iStart)
    {
        // nothing
    }
};

template<typename algorithmFPType, typename IndexType, CpuType cpu>
class DefaultPartitionTask: public PartitionTaskBase<algorithmFPType, IndexType, cpu>
{
public:
    using super             = PartitionTaskBase<algorithmFPType, IndexType, cpu>;
    using SharedDataType    = typename super::SharedDataType;
    using NodeInfoType      = typename super::NodeInfoType;
    using ImpurityType      = typename super::ImpurityType;
    using SplitDataType     = typename super::SplitDataType;
    using IndexTypeVector   = typename super::IndexTypeVector;

    DefaultPartitionTask(size_t iFeature, DAAL_INT idxFeatureValueBestSplit, SharedDataType& sharedData, const NodeInfoType& nodeInfo, SplitDataType& bestSplit):
        super(iFeature, idxFeatureValueBestSplit, sharedData, nodeInfo, bestSplit)
    {
    }

protected:
    virtual void finalizeBestSplit(size_t n, size_t iStart)
    {
        DAAL_ASSERT(_bestSplit.nLeft > 0);
        const DAAL_INT iRowSplitVal = doPartition(n, iStart, _bestSplit, _iFeature, _idxFeatureValueBestSplit);
        DAAL_ASSERT(iRowSplitVal >= 0);
        _bestSplit.iStart = 0;
        if(_sharedData.ctx.dataHelper().indexedFeatures().isBinned(_iFeature))
            _bestSplit.featureValue = (algorithmFPType)_sharedData.ctx.dataHelper().indexedFeatures().binRightBorder(_iFeature, _idxFeatureValueBestSplit);
        else
            _bestSplit.featureValue = _sharedData.ctx.dataHelper().getValue(_iFeature, iRowSplitVal);
    }

    DAAL_INT doPartition(size_t n, size_t iStart, SplitDataType& split, IndexType iFeature, size_t idxFeatureValueBestSplit)
    {
        return doPartitionIdx(n, _sharedData.aIdx + iStart, _sharedData.ctx.dataHelper().indexedFeatures().data(iFeature),
                    split.featureUnordered, idxFeatureValueBestSplit, _sharedData.bestSplitIdxBuf + (2*iStart), split.nLeft);
    }

    DAAL_INT doPartitionIdx(IndexType n, IndexType* aIdx, const IndexType* indexedFeature, bool featureUnordered,
        IndexType idxFeatureValueBestSplit, IndexType* buffer, IndexType nLeft)
    {
        DAAL_INT iRowSplitVal = -1;

        const size_t  maxNBlocks = 56;
        size_t sizeOfBlock = 2048;
        size_t nBlocks = n/sizeOfBlock;
        nBlocks += !!(n - nBlocks*sizeOfBlock);

        if (nBlocks > maxNBlocks)
        {
            nBlocks = maxNBlocks;
            sizeOfBlock = n/nBlocks + !!(n%nBlocks);
        }

        IndexType part_high_left[maxNBlocks];
        IndexType part_high_right[maxNBlocks];

        LoopHelper<cpu>::run(true, nBlocks, [&](size_t iBlock)
        {
            IndexType iLeft = 0;
            IndexType iRight = 0;
            const size_t iStart = iBlock*sizeOfBlock;
            const size_t iEnd = (((iBlock+1) * sizeOfBlock > n) ?  n : iStart + sizeOfBlock);

            IndexType* bestSplitIdx = buffer + 2*iStart;
            IndexType* bestSplitIdxRight = bestSplitIdx + iEnd-iStart;

            IndexType i = iStart;

            if (featureUnordered)
            {
                PRAGMA_IVDEP
                PRAGMA_VECTOR_ALWAYS
                for(IndexType i = iStart; i < iEnd; ++i)
                {
                    if(indexedFeature[aIdx[i]] != idxFeatureValueBestSplit)
                        bestSplitIdxRight[iRight++] = aIdx[i];
                    else
                        bestSplitIdx[iLeft++] = aIdx[i];
                }
            }
            else
            {
                PRAGMA_IVDEP
                PRAGMA_VECTOR_ALWAYS
                for(IndexType i = iStart; i < iEnd; ++i)
                {
                    if(indexedFeature[aIdx[i]] > idxFeatureValueBestSplit)
                        bestSplitIdxRight[iRight++] = aIdx[i];
                    else
                        bestSplitIdx[iLeft++] = aIdx[i];
                }
            }

            part_high_left[iBlock] = iLeft;
            part_high_right[iBlock] = iRight;
        });

        LoopHelper<cpu>::run(true, nBlocks, [&](size_t iBlock)
        {
            const size_t iStart = iBlock*sizeOfBlock;
            const size_t iEnd = (((iBlock+1) * sizeOfBlock > n) ?  n : iStart + sizeOfBlock);

            const IndexType sizeL = part_high_left[iBlock];
            const IndexType sizeR = part_high_right[iBlock];

            IndexType offsetLeft = 0;
            IndexType offsetRight = 0;

            for(IndexType i = 0; i < iBlock; ++i)
            {
                offsetLeft  += part_high_left[i];
                offsetRight += part_high_right[i];
            }

            IndexType* bestSplitIdx = buffer + 2*iStart;
            IndexType* bestSplitIdxRight = bestSplitIdx + iEnd-iStart;

            services::internal::tmemcpy<IndexType, cpu>(aIdx + nLeft + offsetRight, bestSplitIdxRight, sizeR);
            services::internal::tmemcpy<IndexType, cpu>(aIdx + offsetLeft, bestSplitIdx, sizeL);
        });

        IndexType i = 0;
        while(indexedFeature[aIdx[i]] != idxFeatureValueBestSplit) i++;
        iRowSplitVal = aIdx[i];

        return iRowSplitVal;
    }

    using super::_iFeature;
    using super::_idxFeatureValueBestSplit;
    using super::_sharedData;
    using super::_nodeInfo;
    using super::_bestSplit;
};

} /* namespace internal */
} /* namespace training */
} /* namespace gbt */
} /* namespace algorithms */
} /* namespace daal */

#endif
