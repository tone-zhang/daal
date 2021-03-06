/* file: LinearRegressionNormEqStep2TrainingReducerAndPrediction.java */
/*******************************************************************************
* Copyright 2017-2018 Intel Corporation.
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
*
* License:
* http://software.intel.com/en-us/articles/intel-sample-source-code-license-agr
* eement/
*******************************************************************************/

package DAAL;

import java.io.*;

import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.*;
import org.apache.hadoop.fs.FileSystem;

import com.intel.daal.data_management.data.HomogenNumericTable;
import com.intel.daal.algorithms.linear_regression.Model;
import com.intel.daal.algorithms.linear_regression.prediction.*;
import com.intel.daal.algorithms.linear_regression.training.*;
import com.intel.daal.data_management.data.*;
import com.intel.daal.services.*;

public class LinearRegressionNormEqStep2TrainingReducerAndPrediction extends
    Reducer<IntWritable, WriteableData, IntWritable, WriteableData> {

    private static final int nDataFeatures   = 10;  /* Number of features in training and testing data sets */
    private static final int nLabelsFeatures = 2;   /* Number of dependent variables that correspond to each observation */
    private static final int nVectors        = 250;

    @Override
    public void reduce(IntWritable key, Iterable<WriteableData> values, Context context)
    throws IOException, InterruptedException {

        DaalContext daalContext = new DaalContext();

        /* Build the final multiple linear regression model on the master node */
        /* Create an algorithm object to train the multiple linear regression model with the normal equations method */
        TrainingDistributedStep2Master linearRegressionTraining = new TrainingDistributedStep2Master(daalContext,
                                                                                                     Double.class, TrainingMethod.normEqDense);
        /* Set partial multiple linear regression models built on local nodes */
        for (WriteableData value : values) {
            PartialResult pr = (PartialResult)value.getObject(daalContext);
            linearRegressionTraining.input.add(MasterInputId.partialModels, pr);
        }

        /* Build and retrieve the final multiple linear regression model */
        linearRegressionTraining.compute();

        TrainingResult trainingResult = linearRegressionTraining.finalizeCompute();
        Model model = trainingResult.get(TrainingResultId.model);

        /* Test the model */
        prediction(daalContext, model, context);

        daalContext.dispose();
    }

    public void prediction(DaalContext daalContext, Model model, Context context) throws IOException, InterruptedException {
        /* Read a data set */
        String dataFilePath = "/Hadoop/LinearRegressionNormEq/data/LinearRegressionNormEq_test.csv";
        String labelsFilePath = "/Hadoop/LinearRegressionNormEq/data/LinearRegressionNormEq_test_labels.csv";

        double[] data = new double[nDataFeatures * nVectors];
        double[] labels = new double[nLabelsFeatures * nVectors];

        readData(dataFilePath, nDataFeatures, nVectors, data);
        readData(labelsFilePath, nLabelsFeatures, nVectors, labels);

        HomogenNumericTable ntData         = new HomogenNumericTable(daalContext, data, nDataFeatures, nVectors);
        HomogenNumericTable expectedLabels = new HomogenNumericTable(daalContext, labels, nLabelsFeatures, nVectors);

        /* Create algorithm objects to predict values of the multiple linear regression model with the default method */
        PredictionBatch linearRegressionPredict = new PredictionBatch(daalContext, Double.class,
                                                                      PredictionMethod.defaultDense);
        /* Provide the input data */
        linearRegressionPredict.input.set(PredictionInputId.data, ntData);
        linearRegressionPredict.input.set(PredictionInputId.model, model);

        /* Compute and retrieve the prediction results */
        PredictionResult predictionResult   = linearRegressionPredict.compute();
        HomogenNumericTable predictedlabels = (HomogenNumericTable)predictionResult.get(PredictionResultId.prediction);

        context.write(new IntWritable(0), new WriteableData(predictedlabels));
        context.write(new IntWritable(1), new WriteableData(expectedLabels));
    }

    private static void readData(String dataset, int nFeatures, int nVectors, double[] data) {
        System.out.println("readData " + dataset);
        try {
            Path pt = new Path(dataset);
            FileSystem fs = FileSystem.get(new Configuration());
            BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(fs.open(pt)));

            int nLine = 0;
            for (String line; ((line = bufferedReader.readLine()) != null) && (nLine < nVectors); nLine++) {
                String[] elements = line.split(",");
                for (int j = 0; j < nFeatures; j++) {
                    data[nLine * nFeatures + j] = Double.parseDouble(elements[j]);
                }
            }
            bufferedReader.close();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }
}
