# ============================================================
# ML WebApp - Pure Nyx Stack
# ============================================================
# A machine learning prediction service using pure Nyx
# No HTML, JS, or Python - pure Nyx syntax!
#
# Uses: NyWeb + Nyml + NyDatabase + NyHttp

let VERSION = "1.0.0";

# ============================================================
# ML MODEL
# ============================================================

# Simple linear regression model for predictions
pub class LinearModel {
    pub let weights: List<Float>;
    pub let bias: Float;
    pub let feature_names: List<String>;
    
    pub fn new(feature_names: List<String>) -> Self {
        return Self {
            weights: feature_names.map(fn(_) -> Float { return 0.0; }),
            bias: 0.0,
            feature_names: feature_names
        };
    }
    
    # Train the model (simple gradient descent)
    pub fn train(self, data: List<Map<String, Float>>, labels: List<Float>, epochs: Int, learning_rate: Float) {
        for epoch in range(epochs) {
            for i in range(len(data)) {
                let prediction = self._predict_single(data[i]);
                let error = labels[i] - prediction;
                
                # Update weights
                for j in range(len(self.weights)) {
                    let feature = self.feature_names[j];
                    if data[i].has(feature) {
                        self.weights[j] = self.weights[j] + (learning_rate * error * data[i][feature]);
                    }
                }
                
                # Update bias
                self.bias = self.bias + (learning_rate * error);
            }
        }
        
        io.println("Training complete!");
    }
    
    fn _predict_single(self, features: Map<String, Float>) -> Float {
        let prediction = self.bias;
        for j in range(len(self.weights)) {
            let feature = self.feature_names[j];
            if features.has(feature) {
                prediction = prediction + (self.weights[j] * features[feature]);
            }
        }
        return prediction;
    }
    
    # Make prediction
    pub fn predict(self, features: Map<String, Float>) -> Float {
        return self._predict_single(features);
    }
    
    # Get model info
    pub fn info(self) -> Map {
        return {
            "weights": self.weights,
            "bias": self.bias,
            "features": self.feature_names
        };
    }
}

# ============================================================
# DATA STORE
# ============================================================

pub class DataStore {
    pub let training_data: List<Map<String, Float>>;
    pub let labels: List<Float>;
    pub let predictions: List<Map>;
    
    pub fn new() -> Self {
        return Self {
            training_data: [],
            labels: [],
            predictions: []
        };
    }
    
    # Add training example
    pub fn add_example(self, features: Map<String, Float>, label: Float) {
        self.training_data.push(features);
        self.labels.push(label);
    }
    
    # Get data summary
    pub fn summary(self) -> Map {
        return {
            "samples": len(self.training_data),
            "features": len(self.training_data) > 0 ? len(self.training_data[0]) : 0
        };
    }
}

# ============================================================
# ML SERVICE
# ============================================================

pub class MLService {
    pub let model: LinearModel;
    pub let data: DataStore;
    pub let trained: Bool;
    
    pub fn new(features: List<String>) -> Self {
        return Self {
            model: LinearModel::new(features),
            data: DataStore::new(),
            trained: false
        };
    }
    
    # Add training data
    pub fn add_data(self, features: Map<String, Float>, label: Float) {
        self.data.add_example(features, label);
    }
    
    # Train model
    pub fn train(self, epochs: Int, learning_rate: Float) -> Map {
        if len(self.data.training_data) == 0 {
            return {"error": "No training data"};
        }
        
        self.model.train(self.data.training_data, self.data.labels, epochs, learning_rate);
        self.trained = true;
        
        return self.model.info();
    }
    
    # Make prediction
    pub fn predict(self, features: Map<String, Float>) -> Map {
        if not self.trained {
            return {"error": "Model not trained"};
        }
        
        let prediction = self.model.predict(features);
        
        # Store prediction
        self.data.predictions.push({
            "input": features,
            "output": prediction,
            "timestamp": current_time_ms()
        });
        
        return {
            "prediction": prediction,
            "features": features
        };
    }
    
    # Get model status
    pub fn status(self) -> Map {
        return {
            "trained": self.trained,
            "data_samples": len(self.data.training_data),
            "predictions": len(self.data.predictions)
        };
    }
}

# ============================================================
# WEB APPLICATION
# ============================================================

# Global ML service instance
let ml_service = MLService::new(["age", "income", "score"]);

# Initialize with sample data
fn init_ml_service() {
    # Add sample training data (e.g., for credit scoring)
    ml_service.add_data({"age": 25.0, "income": 50000.0, "score": 650.0}, 1.0);
    ml_service.add_data({"age": 35.0, "income": 75000.0, "score": 720.0}, 1.0);
    ml_service.add_data({"age": 45.0, "income": 60000.0, "score": 680.0}, 0.0);
    ml_service.add_data({"age": 55.0, "income": 90000.0, "score": 780.0}, 1.0);
    ml_service.add_data({"age": 30.0, "income": 45000.0, "score": 590.0}, 0.0);
    
    # Train the model
    let result = ml_service.train(100, 0.01);
    io.println("ML Service initialized: " + result as String);
}

# API Handlers

# Health check
fn handle_health(req: Map) -> Map {
    return {
        "status": "healthy",
        "version": VERSION,
        "service": "ML Prediction API"
    };
}

# Get model status
fn handle_status(req: Map) -> Map {
    return ml_service.status();
}

# Get training data summary
fn handle_data(req: Map) -> Map {
    return ml_service.data.summary();
}

# Train model
fn handle_train(req: Map) -> Map {
    let epochs = req.get("epochs") as Int? or 100;
    let lr = req.get("learning_rate") as Float? or 0.01;
    
    return ml_service.train(epochs, lr);
}

# Make prediction
fn handle_predict(req: Map) -> Map {
    let body = req.get("body") as Map?;
    
    if body == null {
        return {"error": "Missing request body"};
    }
    
    # Extract features
    let features: Map<String, Float> = {};
    
    if body.has("age") { features["age"] = body["age"] as Float; }
    if body.has("income") { features["income"] = body["income"] as Float; }
    if body.has("score") { features["score"] = body["score"] as Float; }
    
    return ml_service.predict(features);
}

# ============================================================
# MAIN
# ============================================================

pub fn main() {
    io.println("========================================");
    io.println("ML WebApp - Pure Nyx Stack");
    io.println("========================================");
    io.println("");
    
    # Initialize ML service
    io.println("Initializing ML Service...");
    init_ml_service();
    
    io.println("");
    io.println("ML Service Status:");
    io.println("  Trained: " + (ml_service.trained ? "Yes" : "No"));
    io.println("  Training samples: " + len(ml_service.data.training_data) as String);
    io.println("");
    
    # Test predictions
    io.println("Testing predictions:");
    
    let test_cases = [
        {"age": 28.0, "income": 55000.0, "score": 670.0},
        {"age": 42.0, "income": 85000.0, "score": 750.0}
    ];
    
    for test in test_cases {
        let result = ml_service.predict(test);
        io.println("  Input: " + test as String);
        io.println("  Prediction: " + result["prediction"] as String);
        io.println("");
    }
    
    io.println("========================================");
    io.println("ML WebApp ready!");
    io.println("");
    io.println("API Endpoints (when served with NyWeb):");
    io.println("  GET  /health          - Health check");
    io.println("  GET  /status         - Model status");
    io.println("  GET  /data           - Training data summary");
    io.println("  POST /train          - Train model");
    io.println("  POST /predict        - Make prediction");
    io.println("");
    io.println("Example usage:");
    io.println('  curl -X POST http://localhost:8080/predict \\');
    io.println('    -H "Content-Type: application/json" \\');
    io.println('    -d \'{"age": 30, "income": 60000, "score": 700}\'');
    io.println("");
    io.println("========================================");
}

# Run main
main();
