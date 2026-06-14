import 'dart:math' as math;

/// Lightweight vector utilities for RAG (cosine similarity etc.).
/// For production on-device RAG use ObjectBox HNSW + real embeddings.
/// Here we use 768-dim stubs (or smaller for demo) + cosine.
class VectorUtils {
  static const int demoDimension = 64; // Smaller for immediate no-ML demo; real Gemma is 768

  /// Generate a deterministic pseudo-embedding from text (hash-based, stable for same text).
  /// In real app this would come from flutter_gemma EmbeddingGemma or cloud.
  static List<double> fakeEmbed(String text, {int dim = demoDimension}) {
    final List<double> vec = List.filled(dim, 0.0);
    final bytes = text.toLowerCase().codeUnits;
    for (int i = 0; i < bytes.length; i++) {
      final idx = i % dim;
      vec[idx] += (bytes[i] % 17) / 17.0;
    }
    // normalize roughly
    final norm = math.sqrt(vec.fold(0.0, (p, e) => p + e * e));
    if (norm > 0) {
      for (int i = 0; i < dim; i++) {
        vec[i] = vec[i] / norm;
      }
    }
    return vec;
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    double na = 0.0;
    double nb = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0.0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }
}
