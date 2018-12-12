/* file: gbt_train_hist_kernel.i */
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
//  Implementation of the main compute-intensive functions for gradient boosted trees training
//  (defaultDense) method.
//--
*/

#ifndef __GBT_TRAIN_SPLIT_HIST_KERNEL_I__
#define __GBT_TRAIN_SPLIT_HIST_KERNEL_I__

#if defined (__INTEL_COMPILER)
  #include <immintrin.h>
#endif

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
namespace hist
{

template<typename algorithmFPType, CpuType cpu>
struct Result
{
    using GHSumType = ghSum<algorithmFPType, cpu>;
    using ImpurityType =  ImpurityData<algorithmFPType, cpu>;

    size_t nUnique;
    size_t iFeature;
    GHSumType* ghSums = nullptr;
    algorithmFPType gTotal;
    algorithmFPType hTotal;

    template<typename DataType>
    void release(DataType& data)
    {
        data.GH_SUMS_BUF->singleGHSums.get(iFeature).returnBlockToStorage(ghSums);
        ghSums = nullptr;
        isReleased = true;
    }
    int isReleased = false;
    bool isFailed = true;
};

template<typename algorithmFPType, typename IndexType, typename ImpurityType, typename GHSumType, typename SplitType, typename ResultType, CpuType cpu>
class MaxImpurityDecreaseHelper
{
public:
    static void find(
            size_t n,
            size_t minObservationsInLeafNode,
            algorithmFPType lambda,
            SplitType& split,
            const ResultType& res,
            DAAL_INT& idxFeatureBestSplit,
            bool featureUnordered, SharedDataForTree<algorithmFPType, IndexType, cpu>& data, size_t iFeature)
    {
        if(featureUnordered)
            findCategorical(n, minObservationsInLeafNode, lambda, split, res, idxFeatureBestSplit);
        else
            findOrdered(n, minObservationsInLeafNode, lambda, split, res, idxFeatureBestSplit, data, iFeature);
    }

    static void findOrdered(
            size_t n,
            size_t minObservationsInLeafNode,
            algorithmFPType lambda,
            SplitType& split,
            const ResultType& res,
            DAAL_INT& idxFeatureBestSplit, SharedDataForTree<algorithmFPType, IndexType, cpu>& data, size_t iFeature)
    {
        const size_t nUnique = res.nUnique;
        auto* aGHSum = res.ghSums;
        size_t nLeft = 0;

        ImpurityType imp(res.gTotal, res.hTotal);

        ImpurityType left;
        algorithmFPType bestImpDecrease = -services::internal::MaxVal<algorithmFPType>::get();

        for(size_t i = 0; i < nUnique; ++i)
        {
            if(!aGHSum[i].n)
                continue;
            nLeft += aGHSum[i].n;
            if((n - nLeft) < minObservationsInLeafNode)
                break;
            left.add(aGHSum[i]);
            if(nLeft < minObservationsInLeafNode)
                continue;

            ImpurityType right(imp, left);
            //the part of the impurity decrease dependent on split itself
            const algorithmFPType impDecrease = left.value(lambda) + right.value(lambda);
            if((impDecrease > bestImpDecrease))
            {
                split.left = left;
                split.nLeft = nLeft;
                idxFeatureBestSplit = i;
                bestImpDecrease = impDecrease;
            }
        }
        split.impurityDecrease = bestImpDecrease;
    }


    static void findCategorical(
            size_t n,
            size_t minObservationsInLeafNode,
            algorithmFPType lambda,
            SplitType& split,
            const ResultType& res,
            DAAL_INT& idxFeatureBestSplit)
    {
        const size_t nUnique = res.nUnique;
        auto* aGHSum = res.ghSums;
        size_t nLeft = 0;

        ImpurityType imp(res.gTotal, res.hTotal);

        ImpurityType left;
        algorithmFPType bestImpDecrease = -services::internal::MaxVal<algorithmFPType>::get();

        for(size_t i = 0; i < nUnique; ++i)
        {
            if((aGHSum[i].n < minObservationsInLeafNode) || ((n - aGHSum[i].n) < minObservationsInLeafNode))
                continue;
            const ImpurityType& left = aGHSum[i];
            ImpurityType right(imp, left);
            //the part of the impurity decrease dependent on split itself
            const algorithmFPType impDecrease = left.value(lambda) + right.value(lambda);
            if(impDecrease > bestImpDecrease)
            {
                idxFeatureBestSplit = i;
                bestImpDecrease = impDecrease;
            }
        }
        if(idxFeatureBestSplit >= 0)
        {
            split.left = (const GHSumType&)aGHSum[idxFeatureBestSplit];
            split.nLeft = aGHSum[idxFeatureBestSplit].n;
        }

        split.impurityDecrease = bestImpDecrease;
    }
};

template<typename algorithmFPType, typename IndexType, typename GHSumType, CpuType cpu>
class GHSumsHelper
{
public:
    static void compute(
            const size_t iStart,
            const size_t n,
            const IndexType* const indexedFeature,
            const IndexType* aIdx,
            const IndexType* aSampleToSourceRow,
            const algorithmFPType* const pgh,
            GHSumType* const aGHSum,
            algorithmFPType& gTotal,
            algorithmFPType& hTotal,
            size_t level)
    {
        if(level)
        {
                computeCommon(iStart, n, indexedFeature, aIdx, pgh, aGHSum, gTotal, hTotal);
        }
        else
        {
            if (aSampleToSourceRow)
                computeCommon(iStart, n, indexedFeature, aIdx, pgh, aGHSum, gTotal, hTotal);
            else
                computeRoot(iStart, n, indexedFeature, aIdx, pgh, aGHSum, gTotal, hTotal);
        }
    }

    static void computeCommon( // TODO: to intrinsics
            const size_t iStart,
            const size_t n,
            const IndexType* const indexedFeature,
            const IndexType* aIdx,
            const algorithmFPType* const pgh,
            GHSumType* const aGHSum,
            algorithmFPType& gTotal,
            algorithmFPType& hTotal)
    {
        aIdx = aIdx + iStart;

        for(size_t i = 0; i < n; ++i)
        {
            const IndexType iSample = aIdx[i];
            const IndexType idx = indexedFeature[iSample];
            auto& sum = aGHSum[idx];
            sum.n++;
            sum.g += pgh[2*iSample];
            sum.h += pgh[2*iSample+1];
            gTotal += pgh[2*iSample];
            hTotal += pgh[2*iSample+1];
        }
    }

    static void computeRoot(
            const size_t iStart,
            const size_t n,
            const IndexType* const indexedFeature,
            const IndexType* aIdx,
            const algorithmFPType* const pgh,
            GHSumType* const aGHSum,
            algorithmFPType& gTotal,
            algorithmFPType& hTotal)
    {
        aIdx = aIdx + iStart;

        for(size_t i = 0; i < n; ++i)
        {
            const IndexType idx = indexedFeature[i];
            auto& sum = aGHSum[idx];
            sum.n++;
            sum.g += pgh[2*i];
            sum.h += pgh[2*i+1];
            gTotal += pgh[2*i];
            hTotal += pgh[2*i+1];
        }
    }
    static void computeDiff(
            const size_t nUnique,
            const GHSumType* const aGHSumPrev,
            const GHSumType* const aGHSumsOther,
            GHSumType* const aGHSums)
    {
        algorithmFPType* aGHSumsFP = (algorithmFPType*) aGHSums;
        algorithmFPType* aGHSumPrevFP = (algorithmFPType*) aGHSumPrev;
        algorithmFPType* aGHSumsOtherFP = (algorithmFPType*) aGHSumsOther;

        PRAGMA_IVDEP
        PRAGMA_VECTOR_ALWAYS
        for(size_t i = 0; i < nUnique*4; ++i)
        {
            aGHSumsFP[i] = aGHSumPrevFP[i] - aGHSumsOtherFP[i];
        }
    }

    static void fillByZero(const size_t nUnique, GHSumType* const aGHSum)
    {
        services::internal::service_memset_seq<algorithmFPType, cpu>((algorithmFPType*)aGHSum, algorithmFPType(0), nUnique*4);
    }
};

template<typename IndexType, typename algorithmFPType, CpuType cpu>
struct ComputeGHSumByRows
{
    static void run(algorithmFPType* aGHSumFP, const IndexType* indexedFeature, const IndexType* aIdx, algorithmFPType* pgh, size_t nFeatures, size_t iStart, size_t iEnd)
    {
        PRAGMA_IVDEP
        for(IndexType i = iStart; i < iEnd; ++i)
        {
            const IndexType* featIdx = indexedFeature + aIdx[i] * nFeatures;

            DAAL_PREFETCH_READ_T0(pgh + 2*aIdx[i+10]);

            for(IndexType j = 0; (j < nFeatures/16 + !!(nFeatures%16)) && i+10 < iEnd; j++)
                DAAL_PREFETCH_READ_T0(indexedFeature + aIdx[i+10]*nFeatures + 16*j);

            PRAGMA_IVDEP
            for(IndexType j = 0; j < nFeatures; j++)
            {
                aGHSumFP[featIdx[j] + 0] += pgh[2*aIdx[i]];
                aGHSumFP[featIdx[j] + 1] += pgh[2*aIdx[i]+1];
                aGHSumFP[featIdx[j] + 2] += 1;
            }
        }
    }
};

template<typename algorithmFPType, typename IndexType, CpuType cpu>
struct MergeGHSums
{
    using GHSumType = ghSum<algorithmFPType, cpu>;

    // TODO: optimize for other compilers
    static void run(const size_t nUnique, const size_t iStart, const size_t iEnd, algorithmFPType** results, const size_t nBlocks, Result<algorithmFPType, cpu>& res)
    {
        algorithmFPType* cur = (algorithmFPType*)res.ghSums;
        algorithmFPType* ptr = results[0] + 4*iStart;

        PRAGMA_IVDEP
        PRAGMA_VECTOR_ALWAYS
        for(size_t i = 0; i < 4*nUnique; i++)
            cur[i] = ptr[i];

        for(size_t iB = 1; iB < nBlocks; ++iB)
        {
            algorithmFPType* ptr = results[iB] + 4*iStart;
            PRAGMA_IVDEP
            PRAGMA_VECTOR_ALWAYS
            for(size_t i = 0; i < 4*nUnique; i++)
                cur[i] += ptr[i];
        }

        PRAGMA_IVDEP
        PRAGMA_VECTOR_ALWAYS
        for(size_t i = 0; i < nUnique; ++i)
        {
            res.gTotal += res.ghSums[i].g;
            res.hTotal += res.ghSums[i].h;
        }
    }
};

#if defined (__INTEL_COMPILER)
    #if __CPUID__(DAAL_CPU) >= __sse42__
        #define SSE42_ALL DAAL_CPU
    #else
        #define SSE42_ALL sse42
    #endif

    #if __CPUID__(DAAL_CPU) >= __avx512_mic__
        #define AVX512_ALL DAAL_CPU
    #else
        #define AVX512_ALL avx512_mic
    #endif

    #if __CPUID__(DAAL_CPU) >= __avx__
        #define AVX_ALL DAAL_CPU
    #else
        #define AVX_ALL avx
    #endif

    template<typename IndexType>
    struct ComputeGHSumByRows<IndexType, float, SSE42_ALL>
    {
        static void run(float* aGHSumFP, const IndexType* indexedFeature, const IndexType* aIdx, float* pgh, size_t nFeatures, size_t iStart, size_t iEnd)
        {
            __m128 adds;
            float* addsPtr = (float*) (&adds);
            addsPtr[2] = 1;
            addsPtr[3] = 0;
            PRAGMA_IVDEP
            for(IndexType i = iStart; i < iEnd; ++i)
            {
                const IndexType* featIdx = indexedFeature + aIdx[i] * nFeatures;

                addsPtr[0] = pgh[2*aIdx[i]];
                addsPtr[1] = pgh[2*aIdx[i]+1];
                DAAL_PREFETCH_READ_T0(pgh + 2*aIdx[i+10]);

                for(IndexType j = 0; (j < nFeatures/16 + !!(nFeatures%16)) && i+10 < iEnd; j++)
                    DAAL_PREFETCH_READ_T0(indexedFeature + aIdx[i+10]*nFeatures + 16*j);

                PRAGMA_IVDEP
                for(IndexType j = 0; j < nFeatures; j++)
                {
                    __m128 hist1    = _mm_load_ps(aGHSumFP + featIdx[j]);
                    __m128 newHist1 = _mm_add_ps(adds, hist1);
                    _mm_store_ps(aGHSumFP + featIdx[j], newHist1);
                }
            }
        }
    };

    template<typename IndexType>
    struct ComputeGHSumByRows<IndexType, double, AVX_ALL>
    {
        static void run(double* aGHSumFP, const IndexType* indexedFeature, const IndexType* aIdx, double* pgh, size_t nFeatures, size_t iStart, size_t iEnd)
        {
            __m256d adds;
            double* addsPtr = (double*) (&adds);
            addsPtr[2] = 1;
            addsPtr[3] = 0;
            PRAGMA_IVDEP
            for(IndexType i = iStart; i < iEnd; ++i)
            {
                const IndexType* featIdx = indexedFeature + aIdx[i] * nFeatures;

                addsPtr[0] = pgh[2*aIdx[i]];
                addsPtr[1] = pgh[2*aIdx[i]+1];
                DAAL_PREFETCH_READ_T0(pgh + 2*aIdx[i+10]);

                for(IndexType j = 0; (j < nFeatures/16 + !!(nFeatures%16)) && i+10 < iEnd; j++)
                    DAAL_PREFETCH_READ_T0(indexedFeature + aIdx[i+10]*nFeatures + 16*j);

                PRAGMA_IVDEP
                for(IndexType j = 0; j < nFeatures; j++)
                {
                    __m256d hist1 = _mm256_load_pd(aGHSumFP + featIdx[j]);
                    __m256d newHist1 = _mm256_add_pd(adds, hist1);
                    _mm256_store_pd(aGHSumFP + featIdx[j], newHist1);
                }
            }
        }
    };

    template<typename algorithmFPType, typename IndexType>
    struct MergeGHSums<algorithmFPType, IndexType, AVX512_ALL>
    {
        using GHSumType = ghSum<algorithmFPType, AVX512_ALL>;

        static void run(const size_t nUnique, const size_t iStart, const size_t iEnd, algorithmFPType** results, const size_t nBlocks, Result<algorithmFPType, AVX512_ALL>& res)
        {
            const size_t align = ((64 - ((size_t)(results[0] + 4*iStart) & 63))&63) / sizeof(algorithmFPType);

            algorithmFPType* cur = (algorithmFPType*)res.ghSums;
            if(4*nUnique > 16 + align)
            {
                size_t i = 0;

                for(; i < align; i++)
                {
                    cur[i] = results[0][4*iStart+i];
                    for(size_t iB = 1; iB < nBlocks; ++iB)
                        cur[i] += results[iB][4*iStart+i];
                }

            #if (__FPTYPE__(DAAL_FPTYPE) == __float__)
                for(; i < 4*nUnique-16; i+=16)
                {
                    __m512 sum = _mm512_load_ps(results[0] + 4*iStart + i);
                    DAAL_PREFETCH_READ_T0(results[0] + 4*iStart + i+16);

                    for(size_t iB = 1; iB < nBlocks; ++iB)
                    {
                        __m512 adder = _mm512_load_ps(results[iB] + 4*iStart + i);
                        sum = _mm512_add_ps(sum, adder);
                        DAAL_PREFETCH_READ_T0(results[iB] + 4*iStart + i+16);
                    }
                    _mm512_store_ps(cur+i, sum);
                }
            #else
                for(; i < 4*nUnique-8; i+=8)
                {
                    __m512d sum = _mm512_load_pd(results[0] + 4*iStart + i);
                    DAAL_PREFETCH_READ_T0(results[0] + 4*iStart + i+8);

                    for(size_t iB = 1; iB < nBlocks; ++iB)
                    {
                        __m512d adder = _mm512_load_pd(results[iB] + 4*iStart + i);
                        sum = _mm512_add_pd(sum, adder);
                        DAAL_PREFETCH_READ_T0(results[iB] + 4*iStart + i+8);
                    }
                    _mm512_store_pd(cur+i, sum);
                }
            #endif

                for(; i < 4*nUnique; i++)
                {
                    cur[i] = results[0][4*iStart+i];
                    for(size_t iB = 1; iB < nBlocks; ++iB)
                        cur[i] += results[iB][4*iStart+i];
                }
            }
            else
            {
                algorithmFPType* ptr = results[0] + 4*iStart;
                for(size_t i = 0; i < 4*nUnique; i++)
                    cur[i] = ptr[i];

                for(size_t iB = 1; iB < nBlocks; ++iB)
                {
                    algorithmFPType* ptr = results[iB] + 4*iStart;
                    for(size_t i = 0; i < 4*nUnique; i++)
                        cur[i] += ptr[i];
                }
            }

            for(size_t i = 0; i < nUnique; ++i)
            {
                res.gTotal += res.ghSums[i].g;
                res.hTotal += res.ghSums[i].h;
            }
        }
    };
#endif

} /* namespace hist */
} /* namespace internal */
} /* namespace training */
} /* namespace gbt */
} /* namespace algorithms */
} /* namespace daal */

#endif
