/* file: gbt_train_updater.i */
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
//  Implementation of tree updaters for gradient boosted trees training
//  (defaultDense) method.
//--
*/

#ifndef __GBT_TRAIN_UPDATER_I__
#define __GBT_TRAIN_UPDATER_I__

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

template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu> class UpdaterByColumns;
template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu> class UpdaterByRows;
template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu> class MergedUpdaterByRows;

template<typename algorithmFPType, typename IndexType, CpuType cpu>
struct MemorySafetySplitMode
{
protected:
    using ThisType         = MemorySafetySplitMode<algorithmFPType, IndexType, cpu>;
    using UpdaterType      = UpdaterByColumns<algorithmFPType, IndexType, ThisType, cpu>;

public:
    using TaskType         = sorting::SplitTask<algorithmFPType, IndexType, cpu>;
    using ResultType       = EmptyResult<cpu>;
    using PartitionType      = PartitionMemSafetyTask<algorithmFPType, IndexType, cpu>;
    using NodesCreatorType = DefaultNodesCreator<algorithmFPType, IndexType, UpdaterType, cpu>;
};

template<typename algorithmFPType, typename IndexType, CpuType cpu>
struct ExactSplitMode
{
protected:
    using ThisType         = ExactSplitMode<algorithmFPType, IndexType, cpu>;
    using UpdaterType      = UpdaterByColumns<algorithmFPType, IndexType, ThisType, cpu>;

public:
    using TaskType         = hist::SplitTaskByColumns<algorithmFPType, IndexType, cpu>;
    using ResultType       = hist::Result<algorithmFPType, cpu>;
    using PartitionType      = DefaultPartitionTask<algorithmFPType, IndexType, cpu>;
    using NodesCreatorType = DefaultNodesCreator<algorithmFPType, IndexType, UpdaterType, cpu>;
};

template<typename algorithmFPType, typename IndexType, CpuType cpu>
struct InexactSplitMode
{
protected:
    using ThisType           = InexactSplitMode<algorithmFPType, IndexType, cpu>;
    using UpdaterType        = UpdaterByRows<algorithmFPType, IndexType, ThisType, cpu>;
    using MergedUpdaterType  = MergedUpdaterByRows<algorithmFPType, IndexType, ThisType, cpu>;

public:
    using ResultType               = hist::Result<algorithmFPType, cpu>;
    using TaskType                 = hist::SplitTaskByColumns<algorithmFPType, IndexType, cpu>;
    using FindBestSplitTask        = hist::FindMaxImpurityDecreaseWithGHSumsReduceTask<algorithmFPType, IndexType, MergedResult<ResultType, cpu>, cpu>;
    using FindBestSplitMergedTask  = hist::FindMaxImpurityDecreaseWithGHSumsReduceTaskMerged<algorithmFPType, IndexType, MergedResult<ResultType, cpu>, cpu>;
    using ComputeGHSumsTask        = hist::ComputeGHSumsByRowsTask<algorithmFPType, IndexType, cpu>;
    using PartitionType              = DefaultPartitionTask<algorithmFPType, IndexType, cpu>;
    using NodesCreatorType         = MergedNodesCreator<algorithmFPType, IndexType, UpdaterType, MergedUpdaterType, cpu>;
};

template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu>
class UpdaterBase: public GbtTask
{
public:
    using SplitTaskType     = typename SplitMode::TaskType;
    using ResultType        = typename SplitMode::ResultType;
    using MergedResultType  = MergedResult<ResultType, cpu>;
    using PartitionTaskType = typename SplitMode::PartitionType;
    using NodesCreatorType  = typename SplitMode::NodesCreatorType;
    using DataType          = SharedDataForTree<algorithmFPType, IndexType, cpu>;
    using NodeInfoType      = SplitJob<algorithmFPType,cpu>;
    using ImpurityType      = ImpurityData<algorithmFPType, cpu>;
    using SplitDataType     = SplitData<algorithmFPType, ImpurityType>;
    using BestSplitType     = typename TreeBuilder<algorithmFPType, cpu>::BestSplit;

    UpdaterBase(DataType& data, NodeInfoType& node):
        _data(data), _node(node), _iFeature(-1)
    {
    }

    virtual ~UpdaterBase() { }

    virtual GbtTask* execute() DAAL_C11_OVERRIDE
    {
        DAAL_INT idxFeatureValueBestSplit = -1; //when sorted feature is used
        findBestSplit(_bestSplit, _iFeature, idxFeatureValueBestSplit);

        if(_iFeature >= 0) // best split has been found
        {
            PartitionTaskType partion(_iFeature, idxFeatureValueBestSplit, _data, _node, _bestSplit);
            partion.execute();
        }

        return nullptr;
    }

    virtual void getNextTasks(GbtTask** newTasks, size_t& nTasks) DAAL_C11_OVERRIDE
    {
        NodesCreatorType kidsCreator(_data, _bestSplit, _node, _result);
        kidsCreator.create(_iFeature, newTasks, nTasks);
    }

protected:
    const IndexType* chooseFeatures()
    {
        if(_data.ctx.nFeatures() == _data.ctx.nFeaturesPerNode())
            return nullptr;
        IndexType* featureSample = _data.memHelper->getFeatureSampleBuf();
        _data.ctx.chooseFeatures(featureSample);
        return featureSample;
    }

    void computeFullImpurityDecrease(SplitDataType& split, const NodeInfoType& node, DAAL_INT& iFeature)
    {
        if (iFeature >= 0)
        {
            // now calculate full impurity decrease
            split.impurityDecrease -= _node.imp.value(_data.ctx.par().lambda);
            if(split.impurityDecrease < _data.ctx.par().minSplitLoss)
                iFeature = -1; //not found
        }
    }

    virtual void findBestSplit(SplitDataType& split, DAAL_INT& iFeature, DAAL_INT& idxFeatureValueBestSplit)
    {
        _result = new (services::internal::service_scalable_malloc<MergedResultType, cpu>(1)) MergedResultType(_data.ctx.nFeaturesPerNode());

        const IndexType* featureSample = chooseFeatures();
        iFeature = -1;

        daal::Mutex mtBestSplit;
        BestSplitType bestSplit(split, _data.ctx.isParallelFeatures() ? &mtBestSplit : nullptr);
        findSplit(featureSample, bestSplit);

        bestSplit.getResult(iFeature, idxFeatureValueBestSplit);
        this->computeFullImpurityDecrease(split, _node, iFeature);

        if(featureSample)
            _data.memHelper->releaseFeatureSampleBuf(const_cast<IndexType*>(featureSample));
    }

    virtual void findSplit(const IndexType* featureSample, BestSplitType& bestSplit) = 0;

protected:
    DataType& _data;
    NodeInfoType _node;
    DAAL_INT _iFeature;
    SplitDataType _bestSplit;
    MergedResultType* _result;
};

template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu>
class UpdaterByColumns: public UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>
{
    using super = UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>;
public:
    UpdaterByColumns(typename super::DataType& data, typename super::NodeInfoType& node): super(data, node) { }

protected:
    virtual void findSplit(const IndexType* featureSample, typename super::BestSplitType& bestSplit) DAAL_C11_OVERRIDE
    {
        LoopHelper<cpu>::run(true, this->_data.ctx.nFeaturesPerNode(), [&](size_t i)
        {
            const DAAL_INT iFeature = featureSample ? featureSample[i] : i;
            DAAL_TYPENAME super::SplitTaskType task(iFeature, this->_data, this->_node, bestSplit, this->_result->res[i]);
            task.execute();
        });
    }
};

template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu>
class UpdaterByRows: public UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>
{
public:
    using super = UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>;
    using GHSumType = ghSum<algorithmFPType, cpu>;

    UpdaterByRows(typename super::DataType& data, typename super::NodeInfoType& node): super(data, node) { }

protected:
    virtual void findSplit(const IndexType* featureSample, typename super::BestSplitType& bestSplit) DAAL_C11_OVERRIDE
    {
        const size_t nRows = this->_node.n;
        const size_t sizeOfBlock = 512;
        size_t nBlocks = nRows/sizeOfBlock;
        nBlocks += !!(nRows - nBlocks*sizeOfBlock);

        TlsGHSumMerge<GHSumForTLS<GHSumType, cpu>, algorithmFPType, cpu>* tls = this->_data.GH_SUMS_BUF->GHForCols.getBlockFromStorage();

        LoopHelper<cpu>::run(true, nBlocks, [&](size_t i)
        {
            DAAL_TYPENAME SplitMode::ComputeGHSumsTask task(i, sizeOfBlock, this->_data, this->_node, tls);
            task.execute();
        });

        algorithmFPType** ptrs = services::internal::service_scalable_malloc<algorithmFPType*, cpu>(nBlocks);
        size_t size;
        tls->reduceTo(ptrs, size);

        LoopHelper<cpu>::run(true, this->_data.ctx.nFeaturesPerNode(), [&](size_t i)
        {
            const DAAL_INT iFeature = featureSample ? featureSample[i] : i;
            DAAL_TYPENAME SplitMode::FindBestSplitTask task(iFeature, nBlocks, this->_data, this->_node, bestSplit,
                    this->_result->res[i], ptrs, size);
            task.execute();
        });

        tls->release();
        this->_data.GH_SUMS_BUF->GHForCols.returnBlockToStorage(tls);
        services::internal::service_scalable_free<algorithmFPType*, cpu>(ptrs);
    }
};

template<typename algorithmFPType, typename IndexType, typename SplitMode, CpuType cpu>
class MergedUpdaterByRows: public UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>
{
public:
    using super = UpdaterBase<algorithmFPType, IndexType, SplitMode, cpu>;
    using ImpurityType      = typename super::ImpurityType;
    using SplitDataType     = typename super::SplitDataType;
    using PartitionTaskType = typename super::PartitionTaskType;
    using ResultType        = typename super::ResultType;
    using NodesCreatorType  = typename super::NodesCreatorType;
    using NodeInfoType      = typename super::NodeInfoType;
    using DataType          = typename super::DataType;
    using BestSplitType     = typename TreeBuilder<algorithmFPType, cpu>::BestSplit;

    using GHSumType = ghSum<algorithmFPType, cpu>;

    MergedUpdaterByRows(DataType& data, NodeInfoType& node1, NodeInfoType& node2, MergedResult<ResultType, cpu>* _prevResult):
        super(data, node1), _node2(node2), _prevRes(_prevResult)
    {
    }

    virtual void findSplit(const IndexType* featureSample, BestSplitType& bestSplit) DAAL_C11_OVERRIDE { }

    virtual GbtTask* execute() DAAL_C11_OVERRIDE
    {
        _result1 = new (services::internal::service_scalable_malloc<MergedResult<ResultType, cpu>, cpu>(1))MergedResult<ResultType, cpu>(_data.ctx.nFeaturesPerNode());
        _result2 = new (services::internal::service_scalable_malloc<MergedResult<ResultType, cpu>, cpu>(1))MergedResult<ResultType, cpu>(_data.ctx.nFeaturesPerNode());

        DAAL_INT idxFeatureValueBestSplit1;
        DAAL_INT idxFeatureValueBestSplit2;

        if (_node1.n < _node2.n) // full GHSums will be computed for 1 node
            findBestSplit(_node1, _node2, _bestSplit1, _bestSplit2, _iFeature1, _iFeature2, idxFeatureValueBestSplit1, idxFeatureValueBestSplit2, _result1, _result2);
        else // full GHSums will be computed for 2 node
            findBestSplit(_node2, _node1, _bestSplit2, _bestSplit1, _iFeature2, _iFeature1, idxFeatureValueBestSplit2, idxFeatureValueBestSplit1, _result2, _result1);

        LoopHelper<cpu>::run(true, 2, [&](size_t i)
        {
            if(_iFeature1 >= 0 && i == 0)
            {
                PartitionTaskType partion(_iFeature1, idxFeatureValueBestSplit1, _data, _node1, _bestSplit1);
                partion.execute();
            }
            if(_iFeature2 >= 0 && i == 1)
            {
                PartitionTaskType partion(_iFeature2, idxFeatureValueBestSplit2, _data, _node2, _bestSplit2);
                partion.execute();
            }
        });

        return nullptr;
    }

    virtual void getNextTasks(GbtTask** newTasks, size_t& nTasks) DAAL_C11_OVERRIDE
    {
        NodesCreatorType kidsCreatorLeft(_data, _bestSplit1, _node1, _result1); // spawns 0 or 1 tasks
        kidsCreatorLeft.create(_iFeature1, newTasks, nTasks);

        NodesCreatorType kidsCreatorRight(_data, _bestSplit2, _node2, _result2); // spawns 0 or 1 tasks
        kidsCreatorRight.create(_iFeature2, newTasks, nTasks);

        if (_prevRes) { _prevRes->release(_data); _prevRes = nullptr; }
    }

protected:
    virtual void findBestSplit(NodeInfoType& node1, NodeInfoType& node2, SplitDataType& split1, SplitDataType& split2, DAAL_INT& iFeature1, DAAL_INT& iFeature2,
        DAAL_INT& idxFeatureValueBestSplit1, DAAL_INT& idxFeatureValueBestSplit2, MergedResult<ResultType, cpu>* result1, MergedResult<ResultType, cpu>* result2)
    {
        const IndexType* featureSample = super::chooseFeatures();

        iFeature1 = -1;
        iFeature2 = -1;

        daal::Mutex mtBestSplit1;
        daal::Mutex mtBestSplit2;
        BestSplitType bestSplit1(split1, _data.ctx.isParallelFeatures() ? &mtBestSplit1 : nullptr);
        BestSplitType bestSplit2(split2, _data.ctx.isParallelFeatures() ? &mtBestSplit2 : nullptr);
        findSplitbyRows(featureSample, bestSplit1, bestSplit2, node1, node2, result1, result2);

        bestSplit1.getResult(iFeature1, idxFeatureValueBestSplit1);
        bestSplit2.getResult(iFeature2, idxFeatureValueBestSplit2);

        if(featureSample)
            _data.memHelper->releaseFeatureSampleBuf(const_cast<IndexType*>(featureSample));

        this->computeFullImpurityDecrease(split1, _node1, iFeature1);
        this->computeFullImpurityDecrease(split2, _node2, iFeature2);
    }


    void findSplitbyRows(const IndexType* featureSample, BestSplitType& bestSplit1, BestSplitType& bestSplit2,
        NodeInfoType& node1, NodeInfoType& node2, MergedResult<ResultType, cpu>* result1, MergedResult<ResultType, cpu>* result2)
    {
        const size_t nRows = node1.n;
        const size_t sizeOfBlock = 512;
        size_t nBlocks = nRows/sizeOfBlock;
        nBlocks += !!(nRows - nBlocks*sizeOfBlock);

        TlsGHSumMerge<GHSumForTLS<GHSumType, cpu>, algorithmFPType, cpu>* tls = _data.GH_SUMS_BUF->GHForCols.getBlockFromStorage();

        LoopHelper<cpu>::run(true, nBlocks, [&](size_t i)
        {
            DAAL_TYPENAME SplitMode::ComputeGHSumsTask task(i, sizeOfBlock, _data, node1, tls);
            task.execute();
        });

        algorithmFPType** ptrs = services::internal::service_scalable_malloc<algorithmFPType*, cpu>(nBlocks);
        size_t size;
        tls->reduceTo(ptrs, size);

        LoopHelper<cpu>::run(true, _data.ctx.nFeaturesPerNode(), [&](size_t i)
        {
            const DAAL_INT iFeature = featureSample ? featureSample[i] : i;
            DAAL_TYPENAME SplitMode::FindBestSplitMergedTask task(iFeature, nBlocks, _data, node1, node2, bestSplit1, bestSplit2,
                _prevRes->res[i], result1->res[i], result2->res[i], ptrs, size);
            task.execute();
        });

        tls->release();
        _data.GH_SUMS_BUF->GHForCols.returnBlockToStorage(tls);
    }

    virtual void findBestSplit(SplitDataType& split, DAAL_INT& iFeature, DAAL_INT& idxFeatureValueBestSplit) DAAL_C11_OVERRIDE {} // TODO: rework to remove

protected:
    using super::_data;
    NodeInfoType& _node1 = super::_node;
    NodeInfoType _node2;

    SplitDataType _bestSplit1;
    SplitDataType _bestSplit2;

    DAAL_INT _iFeature1 = -1;
    DAAL_INT _iFeature2 = -1;

    MergedResult<ResultType, cpu>* _prevRes;
    MergedResult<ResultType, cpu>* _result1;
    MergedResult<ResultType, cpu>* _result2;
};

} /* namespace internal */
} /* namespace training */
} /* namespace gbt */
} /* namespace algorithms */
} /* namespace daal */

#endif
