/* file: gbt_train_split_sorting.i */
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
//  Implementation of sorting method for gradient boosted trees training
//  (defaultDense) method.
//--
*/

#ifndef __GBT_TRAIN_SPLIT_SORTING_I__
#define __GBT_TRAIN_SPLIT_SORTING_I__

#include "dtrees_model_impl.h"
#include "dtrees_train_data_helper.i"
#include "dtrees_predict_dense_default_impl.i"
#include "gbt_train_aux.i"

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

template<typename algorithmFPType, CpuType cpu> class TreeBuilder;

namespace sorting
{

template<typename algorithmFPType, typename IndexType, CpuType cpu>
class SplitTask: public GbtTask
{
public:
    using SharedDataType = SharedDataForTree<algorithmFPType, IndexType, cpu>;
    using NodeInfoType   = SplitJob<algorithmFPType,cpu>;
    using ResultType     = EmptyResult<cpu>;
    using ImpurityType   = ImpurityData<algorithmFPType, cpu>;
    using SplitDataType  = SplitData<algorithmFPType, ImpurityType>;
    using BestSplitType  = typename TreeBuilder<algorithmFPType, cpu>::BestSplit;
    using IndexTypeVector = TVector<IndexType, cpu>;

    SplitTask(size_t iFeature, SharedDataType& sharedData, const NodeInfoType& nodeInfo, BestSplitType& bestSplit, ResultType& res):
        _iFeature(iFeature), _sharedData(sharedData), _nodeInfo(nodeInfo), _bestSplit(bestSplit), _res(res)
    {
    }

    virtual GbtTask* execute()
    {
        IndexType* aIdx = _sharedData.aIdx + _nodeInfo.iStart;

        const bool bThreaded = _bestSplit.isThreadedMode();
        IndexType* bestSplitIdx = _sharedData.bestSplitIdxBuf + _nodeInfo.iStart;
        auto aFeatBuf = _sharedData.memHelper->getFeatureValueBuf(_nodeInfo.n);

        IndexTypeVector* aFeatIdxBuf = nullptr;
        if(bThreaded)
        {
            //get a local index, since it is used by parallel threads
            aFeatIdxBuf = _sharedData.memHelper->getSortedFeatureIdxBuf(_nodeInfo.n);
            services::internal::tmemcpy<IndexType, cpu>(aFeatIdxBuf->get(), aIdx, _nodeInfo.n);
            aIdx = aFeatIdxBuf->get();
        }
        algorithmFPType* featBuf = aFeatBuf->get();
        _sharedData.ctx.featureValuesToBuf(_iFeature, featBuf, aIdx, _nodeInfo.n);
        if(featBuf[_nodeInfo.n - 1] - featBuf[0] <= _sharedData.ctx.accuracy()) //all values of the feature are the same
        {
            _sharedData.memHelper->releaseFeatureValueBuf(aFeatBuf);
            if(aFeatIdxBuf)
                _sharedData.memHelper->releaseSortedFeatureIdxBuf(aFeatIdxBuf);
            return nullptr;
        }
        //use best split estimation when searching on iFeature
        algorithmFPType bestImpDec;
        int iBestFeat;
        _bestSplit.safeGetData(bestImpDec, iBestFeat);
        SplitDataType split(bestImpDec, _sharedData.ctx.featTypes().isUnordered(_iFeature));
        bool bFound = findBestSplitFeatSorted(featBuf, aIdx, split, iBestFeat < 0 || iBestFeat > _iFeature);
        _sharedData.memHelper->releaseFeatureValueBuf(aFeatBuf);
        if(bFound)
        {
            DAAL_ASSERT(split.iStart < _nodeInfo.n);
            DAAL_ASSERT(split.iStart + split.nLeft <= _nodeInfo.n);

            _bestSplit.update(split, _iFeature, bestSplitIdx, aIdx, _nodeInfo.n);
        }
        if(aFeatIdxBuf)
            _sharedData.memHelper->releaseSortedFeatureIdxBuf(aFeatIdxBuf);

        return nullptr;
    }

protected:

    bool findBestSplitFeatSorted(const algorithmFPType* featureVal, const IndexType* aIdx, SplitDataType& split, bool bUpdateWhenTie) const
    {
        return split.featureUnordered ? findBestSplitCategorical(featureVal, aIdx, split, bUpdateWhenTie) :
            findBestSplitOrdered(featureVal, aIdx,  split, bUpdateWhenTie);
    }

    bool findBestSplitOrdered(const algorithmFPType* featureVal, const IndexType* aIdx, SplitDataType& split, bool bUpdateWhenTie) const
    {
        ImpurityType left(_sharedData.ctx.grad(_sharedData.iTree)[*aIdx]);
        algorithmFPType bestImpurityDecrease = split.impurityDecrease;
        IndexType iBest = -1;
        const size_t n = _nodeInfo.n;
        const auto nMinSplitPart = _sharedData.ctx.par().minObservationsInLeafNode;
        const algorithmFPType last = featureVal[n - nMinSplitPart];
        for(size_t i = 1; i < (n - nMinSplitPart + 1); ++i)
        {
            const bool bSameFeaturePrev(featureVal[i] <= featureVal[i - 1] + _sharedData.ctx.accuracy());
            if(!(bSameFeaturePrev || i < nMinSplitPart))
            {
                //can make a split
                //nLeft == i, nRight == n - i
                ImpurityType right(_nodeInfo.imp, left);
                const algorithmFPType v = left.value(_sharedData.ctx.par().lambda) + right.value(_sharedData.ctx.par().lambda);
                if((v > bestImpurityDecrease) || (bUpdateWhenTie && (v == bestImpurityDecrease)))
                {
                    bestImpurityDecrease = v;
                    split.left = left;
                    iBest = i;
                }
            }

            //update impurity and continue
            left.add(_sharedData.ctx.grad(_sharedData.iTree)[aIdx[i]]);
        }
        if(iBest < 0)
            return false;

        split.impurityDecrease = bestImpurityDecrease;
        split.nLeft = iBest;
        split.iStart = 0;
        split.featureValue = featureVal[iBest - 1];
        return true;
    }

    bool findBestSplitCategorical(const algorithmFPType* featureVal, const IndexType* aIdx, SplitDataType& split, bool bUpdateWhenTie) const
    {
        const size_t n = _nodeInfo.n;
        const auto nMinSplitPart = _sharedData.ctx.par().minObservationsInLeafNode;
        DAAL_ASSERT(n >= 2 * nMinSplitPart);
        algorithmFPType bestImpurityDecrease = split.impurityDecrease;
        ImpurityType left;
        bool bFound = false;
        size_t nDiffFeatureValues = 0;
        for(size_t i = 0; i < n - nMinSplitPart;)
        {
            ++nDiffFeatureValues;
            size_t count = 1;
            const algorithmFPType first = featureVal[i];
            const size_t iStart = i;
            for(++i; (i < n) && (featureVal[i] == first); ++count, ++i);
            if((count < nMinSplitPart) || ((n - count) < nMinSplitPart))
                continue;

            if((i == n) && (nDiffFeatureValues == 2) && bFound)
                break; //only 2 feature values, one possible split, already found

            calcImpurityIndirect(aIdx + iStart, count, left);
            ImpurityType right(_nodeInfo.imp, left);
            const algorithmFPType v = left.value(_sharedData.ctx.par().lambda) + right.value(_sharedData.ctx.par().lambda);
            if(v > bestImpurityDecrease || (bUpdateWhenTie && (v == bestImpurityDecrease)))
            {
                bestImpurityDecrease = v;
                split.left = left;
                split.nLeft = count;
                split.iStart = iStart;
                split.featureValue = first;
                bFound = true;
            }
        }
        if(bFound)
            split.impurityDecrease = bestImpurityDecrease;
        return bFound;
    }

    void calcImpurityIndirect(const IndexType* aIdx, size_t n, ImpurityType& imp) const // move to common code
    {
        DAAL_ASSERT(n);
        const algorithmFPType* pgh = (const algorithmFPType*) _sharedData.ctx.grad(_sharedData.iTree);
        imp = _sharedData.ctx.grad(_sharedData.iTree)[aIdx[0]];

        PRAGMA_VECTOR_ALWAYS
        for(size_t i = 1; i < n; ++i)
        {
            imp.g += pgh[2*aIdx[i]];
            imp.h += pgh[2*aIdx[i]+1];
        }
    }

    const size_t _iFeature;
    SharedDataType& _sharedData;
    const NodeInfoType& _nodeInfo;
    ResultType& _res;
    BestSplitType& _bestSplit;
};

} /* namespace hist */
} /* namespace internal */
} /* namespace training */
} /* namespace gbt */
} /* namespace algorithms */
} /* namespace daal */

#endif
