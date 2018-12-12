/* file: gbt_train_tree_builder.i */
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
//  Implementation of auxiliary functions for gradient boosted trees training
//  (defaultDense) method.
//--
*/

#ifndef __GBT_TRAIN_TREE_BUILDER_I__
#define __GBT_TRAIN_TREE_BUILDER_I__

#include "dtrees_model_impl.h"
#include "dtrees_train_data_helper.i"
#include "dtrees_predict_dense_default_impl.i"
#include "gbt_train_aux.i"
#include "gbt_train_partion.i"
#include "gbt_train_split_hist.i"
#include "gbt_train_split_sorting.i"
#include "gbt_train_node_creator.i"
#include "gbt_train_updater.i"

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

using namespace daal::algorithms::dtrees::training::internal;
using namespace daal::algorithms::gbt::internal;

template<typename algorithmFPType, CpuType cpu>
class TreeBuilder : public TreeBuilderBase
{
public:
    typedef TrainBatchTaskBaseXBoost<algorithmFPType, cpu> CommonCtx;
    using MemHelperType = MemHelperBase<algorithmFPType, cpu>;
    typedef typename CommonCtx::DataHelperType DataHelperType;

    typedef gh<algorithmFPType, cpu> ghType;
    typedef ghSum<algorithmFPType, cpu> ghSumType;
    typedef SplitJob<algorithmFPType, cpu> SplitJobType;
    typedef gbt::internal::TreeImpRegression<> TreeType;
    typedef typename TreeType::NodeType NodeType;
    typedef ImpurityData<algorithmFPType, cpu> ImpurityType;
    typedef SplitData<algorithmFPType, ImpurityType> SplitDataType;

    class BestSplit
    {
    public:
        BestSplit(SplitDataType& split, Mutex* mt) :
            _split(split), _mt(mt), _iIndexedFeatureSplitValue(-1), _iFeature(-1){}
        void safeGetData(algorithmFPType& impDec, int& iFeature)
        {
            if(_mt)
            {
                _mt->lock();
                impDec = impurityDecrease();
                iFeature = _iFeature;
                _mt->unlock();
            }
            else
            {
                impDec = impurityDecrease();
                iFeature = _iFeature;
            }
        }
        void update(const SplitDataType& split, int iIndexedFeatureSplitValue, int iFeature)
        {
            if(_mt)
            {
                _mt->lock();
                updateImpl(split, iIndexedFeatureSplitValue, iFeature);
                _mt->unlock();
            }
            else
                updateImpl(split, iIndexedFeatureSplitValue, iFeature);
        }

        void update(const SplitDataType& split, int iFeature, IndexType* bestSplitIdx, const IndexType* aIdx, size_t n)
        {
            if(_mt)
            {
                _mt->lock();
                if(updateImpl(split, -1, iFeature))
                    services::internal::tmemcpy<IndexType, cpu>(bestSplitIdx, aIdx, n);
                _mt->unlock();
            }
            else
            {
                if(updateImpl(split, -1, iFeature))
                    services::internal::tmemcpy<IndexType, cpu>(bestSplitIdx, aIdx, n);
            }
        }

        void getResult(DAAL_INT& ifeature, DAAL_INT& indexedFeatureSplitValue)
        {
            ifeature = iFeature();
            indexedFeatureSplitValue = iIndexedFeatureSplitValue();
        }

        int iIndexedFeatureSplitValue() const { return _iIndexedFeatureSplitValue; }
        int iFeature() const { return _iFeature; }
        bool isThreadedMode() const { return _mt != nullptr; }

    private:
        algorithmFPType impurityDecrease() const { return _split.impurityDecrease; }
        bool updateImpl(const SplitDataType& split, int iIndexedFeatureSplitValue, int iFeature)
        {
            if(split.impurityDecrease < impurityDecrease())
                return false;

            if(split.impurityDecrease == impurityDecrease())
            {
                if(_iFeature < (int)iFeature) //deterministic way, let the split be the same as in sequential case
                    return false;
            }
            _iFeature = (int)iFeature;
            split.copyTo(_split);
            _iIndexedFeatureSplitValue = iIndexedFeatureSplitValue;
            return true;
        }

    private:
        SplitDataType& _split;
        Mutex* _mt;
        IndexType _iIndexedFeatureSplitValue;
        DAAL_INT _iFeature;
    };

    TreeBuilder(CommonCtx& ctx) : _ctx(ctx){}
    ~TreeBuilder()
    {
        delete _memHelper;
        delete _taskGroup;
    }

    bool isInitialized() const { return !!_aBestSplitIdxBuf.get(); }
    virtual services::Status run(gbt::internal::GbtDecisionTree*& pRes, HomogenNumericTable<double>*& pTblImp,
        HomogenNumericTable<int>*& pTblSmplCnt, size_t iTree, GlobalStorages<algorithmFPType, cpu>& GH_SUMS_BUF);

    virtual services::Status run(gbt::internal::GbtDecisionTree*& pRes, HomogenNumericTable<double>*& pTblImp,
        HomogenNumericTable<int>*& pTblSmplCnt, size_t iTree ) DAAL_C11_OVERRIDE { return services::Status(); }
    virtual services::Status init() DAAL_C11_OVERRIDE
    {
        _aBestSplitIdxBuf.reset(_ctx.nSamples()*2);
        _aSample.reset(_ctx.nSamples());
        DAAL_CHECK_MALLOC(_aBestSplitIdxBuf.get() && _aSample.get());
        DAAL_CHECK_MALLOC(initMemHelper());
        if(_ctx.isParallelNodes() && !_taskGroup)
            DAAL_CHECK_MALLOC((_taskGroup = new daal::task_group()));
        return services::Status();
    }
    daal::task_group* taskGroup() { return _taskGroup; }
    static TreeBuilder<algorithmFPType, cpu>* create(CommonCtx& ctx);

protected:
    bool initMemHelper();
    //find features to check in the current split node
    const IndexType* chooseFeatures()
    {
        if(_ctx.nFeatures() == _ctx.nFeaturesPerNode())
            return nullptr;
        IndexType* featureSample = _memHelper->getFeatureSampleBuf();
        _ctx.chooseFeatures(featureSample);
        return featureSample;
    }

    class TaskForker: public GbtTask
    {
    public:
        typedef TreeBuilder<algorithmFPType, cpu> BuilderType;
        typedef TrainBatchTaskBaseXBoost<algorithmFPType, cpu> CommonCtx;

        TaskForker(GbtTask* o, CommonCtx& ctx, BuilderType* builder): _task(o), _ctx(ctx), _builder(builder)
        {
        }

        virtual void operator()()
        {
            _builder->buildSplit(_task);
        }
        virtual GbtTask* execute() { return nullptr; }

    protected:
        CommonCtx& _ctx;
        GbtTask* _task;
        BuilderType* _builder;
    };


    void buildNode(TaskForker& task);
    IndexType* bestSplitIdxBuf() const { return _aBestSplitIdxBuf.get(); }
    NodeType::Base* buildRoot(size_t iTree, GlobalStorages<algorithmFPType, cpu>& GH_SUMS_BUF)
    {
        _iTree = iTree;
        const size_t nSamples = _ctx.nSamples();
        auto aSample = _aSample.get();

        if (_ctx.isBagging()) // make a copy
        {
            const IndexType* const aSampleToF = _ctx.aSampleToF();
            for(size_t i = 0; i < nSamples; ++i)
                aSample[i] = aSampleToF[i];
        }
        else  // use of all data
        {
            for(size_t i = 0; i < nSamples; ++i)
                aSample[i] = i;
        }

        ImpurityType imp;
        getInitialImpurity(imp);
        typename NodeType::Base* res = buildLeaf(0, nSamples, 0, imp); // use node creater
        if(res)
            return res;

        SplitJobType job(0, nSamples, 0, imp, res);
        SharedDataForTree<algorithmFPType, IndexType, cpu> data(_ctx, bestSplitIdxBuf(), const_cast<IndexType*>(_aSample.get()), _memHelper, this->_iTree, _tree, _mtAlloc);
        data.GH_SUMS_BUF = &GH_SUMS_BUF;

        if(_ctx.par().memorySavingMode)
        {
            using Mode = MemorySafetySplitMode<algorithmFPType, IndexType, cpu>;
            using Updater = UpdaterByColumns<algorithmFPType, IndexType, Mode, cpu>;
            buildSplit(new (service_scalable_malloc<Updater, cpu>(1)) Updater(data, job));
        }
        else if (_ctx.par().splitMethod == gbt::training::exact || _ctx.nFeatures() != _ctx.nFeaturesPerNode())
        {
            using Mode = ExactSplitMode<algorithmFPType, IndexType, cpu>;
            using Updater = UpdaterByColumns<algorithmFPType, IndexType, Mode, cpu>;
            buildSplit(new (service_scalable_malloc<Updater, cpu>(1)) Updater(data, job));
        }
        else
        {
            using Mode = InexactSplitMode<algorithmFPType, IndexType, cpu>;
            using Updater = UpdaterByRows<algorithmFPType, IndexType, Mode, cpu>;
            buildSplit(new (service_scalable_malloc<Updater, cpu>(1)) Updater(data, job));
        }

        if(taskGroup())
            taskGroup()->wait();

        return res;
    }

    void getInitialImpurity(ImpurityType& val)
    {
        const ghType* pgh = _ctx.grad(this->_iTree);
        auto& G = val.g;
        auto& H = val.h;
        G = H = 0;

        const size_t nSamples = _ctx.nSamples();
        const IndexType* aSampleToF = _ctx.aSampleToF();

        if(aSampleToF)
        {
            PRAGMA_VECTOR_ALWAYS
            for(size_t i = 0; i < nSamples; ++i)
            {
                G += pgh[aSampleToF[i]].g;
                H += pgh[aSampleToF[i]].h;
            }
        }
        else
        {
            PRAGMA_VECTOR_ALWAYS
            for(size_t i = 0; i < nSamples; ++i)
            {
                G += pgh[i].g;
                H += pgh[i].h;
            }
        }
    }

    NodeType::Base* buildLeaf(size_t iStart, size_t n, size_t level, const ImpurityType& imp)
    {
        return _ctx.terminateCriteria(n, level, imp) ? makeLeaf(_aSample.get() + iStart, n, imp) : nullptr;
    }

    typename NodeType::Leaf* makeLeaf(const IndexType* idx, size_t n, const ImpurityType& imp)
    {
        typename NodeType::Leaf* pNode = nullptr;
        if(_ctx.isThreaded())
        {
            _mtAlloc.lock();
            pNode = _tree.allocator().allocLeaf();
            _mtAlloc.unlock();
        }
        else
            pNode = _tree.allocator().allocLeaf();
        pNode->response = _ctx.computeLeafWeightUpdateF(idx, n, imp, _iTree);
        pNode->count = n;
        pNode->impurity = imp.value(_ctx.par().lambda);
        return pNode;
    }
    void buildSplit(GbtTask* task);

protected:
    CommonCtx& _ctx;
    size_t _iTree = 0;
    TreeType _tree;
    daal::Mutex _mtAlloc;
    typedef dtrees::internal::TVector<IndexType, cpu> IndexTypeArray;
    mutable IndexTypeArray _aBestSplitIdxBuf;
    mutable IndexTypeArray _aSample;
    MemHelperType* _memHelper = nullptr;
    daal::task_group* _taskGroup = nullptr;
};

template <typename algorithmFPType, CpuType cpu>
bool TreeBuilder<algorithmFPType, cpu>::initMemHelper()
{
    auto featuresSampleBufSize = 0; //do not allocate if not required
    const auto nFeat = _ctx.nFeatures();
    if(nFeat != _ctx.nFeaturesPerNode())
    {
        if(_ctx.nFeaturesPerNode()*_ctx.nFeaturesPerNode() < 2 * nFeat)
            featuresSampleBufSize = 2 * _ctx.nFeaturesPerNode();
        else
            featuresSampleBufSize = nFeat;
    }
    if(_ctx.isThreaded())
        _memHelper = new MemHelperThr<algorithmFPType, cpu>(featuresSampleBufSize);
    else
        _memHelper = new MemHelperSeq<algorithmFPType, cpu>(featuresSampleBufSize,
        _ctx.par().memorySavingMode ? 0 : _ctx.dataHelper().indexedFeatures().maxNumIndices(),
        _ctx.nSamples());
    return _memHelper && _memHelper->init();
}

template <typename algorithmFPType, CpuType cpu>
void TreeBuilder<algorithmFPType, cpu>::buildNode(TaskForker& task)
{
    if(taskGroup())
        taskGroup()->run(task);
    else
        buildSplit(&task);
}

template <typename algorithmFPType, CpuType cpu>
services::Status TreeBuilder<algorithmFPType, cpu>::run(gbt::internal::GbtDecisionTree*& pRes,
    HomogenNumericTable<double>*& pTblImp, HomogenNumericTable<int>*& pTblSmplCnt, size_t iTree, GlobalStorages<algorithmFPType, cpu>& GH_SUMS_BUF)
{
    _tree.destroy();
    typename NodeType::Base* nd = buildRoot(iTree, GH_SUMS_BUF);
    DAAL_CHECK_MALLOC(nd);

    _tree.reset(nd, false);
    gbt::internal::ModelImpl::treeToTable(_tree, &pRes, &pTblImp, &pTblSmplCnt);

    if(_ctx.isBagging() && _tree.top())
        _ctx.updateOOB(iTree, _tree);

    return services::Status();
}

template <typename algorithmFPType, CpuType cpu>
void TreeBuilder<algorithmFPType, cpu>::buildSplit(GbtTask* task)
{
    task->execute();

    GbtTask* newTasks[2];
    size_t nTasks = 0;

    task->getNextTasks(newTasks, nTasks); // returns 0, 1 or 2 tasks

    task->~GbtTask();
    service_scalable_free<GbtTask,cpu>(task);

    if(nTasks == 1)
    {
        buildSplit(newTasks[0]);
    }
    else if(nTasks == 2)
    {
        if(_ctx.numAvailableThreads())
        {
            TaskForker newTask(newTasks[0], _ctx, this);
            buildNode(newTask);
        }
        else
            buildSplit(newTasks[0]);
        buildSplit(newTasks[1]);
    }
}

template <typename algorithmFPType, CpuType cpu>
TreeBuilder<algorithmFPType, cpu>* TreeBuilder<algorithmFPType, cpu>::create(CommonCtx& ctx)
{
    return new TreeBuilder<algorithmFPType, cpu>(ctx);
}

} /* namespace internal */
} /* namespace training */
} /* namespace gbt */
} /* namespace algorithms */
} /* namespace daal */

#endif
