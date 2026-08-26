import Flutter
import Foundation

enum FlorienLlamaError: LocalizedError {
  case unavailable
  case missingPath
  case loadFailed
  case generateFailed

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "On-device AI needs a physical iPhone."
    case .missingPath:
      return "Model path is missing."
    case .loadFailed:
      return "The AI model couldn’t load."
    case .generateFailed:
      return "The AI model couldn’t answer."
    }
  }
}

enum FlorienLlamaChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "florien/llama", binaryMessenger: messenger)
    let queue = DispatchQueue(label: "co.florien.llama", qos: .userInitiated)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "load":
        let values = call.arguments as? [String: Any]
        let path = values?["path"] as? String
        let nGpuLayers = values?["nGpuLayers"] as? Int
        queue.async {
          do {
            try FlorienLlamaEngine.shared.load(path: path, nGpuLayers: nGpuLayers)
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(
                FlutterError(
                  code: "llama_load_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      case "complete":
        let values = call.arguments as? [String: Any]
        let prompt = values?["prompt"] as? String ?? ""
        let maxTokens = values?["maxTokens"] as? Int ?? 280
        queue.async {
          do {
            let text = try FlorienLlamaEngine.shared.complete(
              prompt: prompt,
              maxTokens: maxTokens
            )
            DispatchQueue.main.async { result(text) }
          } catch {
            DispatchQueue.main.async {
              result(
                FlutterError(
                  code: "llama_complete_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

#if canImport(llama)
import llama

final class FlorienLlamaEngine {
  static let shared = FlorienLlamaEngine()

  private var model: OpaquePointer?
  private var context: OpaquePointer?
  private var vocab: OpaquePointer?
  private var loadedPath: String?

  func load(path: String?, nGpuLayers: Int?) throws {
    guard let path, !path.isEmpty else { throw FlorienLlamaError.missingPath }
    if loadedPath == path, context != nil { return }
    unload()
    llama_backend_init()
    var modelParams = llama_model_default_params()
    modelParams.n_gpu_layers = Int32(nGpuLayers ?? 99)
    guard let loaded = llama_model_load_from_file(path, modelParams) else {
      throw FlorienLlamaError.loadFailed
    }
    var ctxParams = llama_context_default_params()
    ctxParams.n_ctx = 2048
    let threads = Int32(max(1, min(6, ProcessInfo.processInfo.processorCount - 2)))
    ctxParams.n_threads = threads
    ctxParams.n_threads_batch = threads
    guard let ctx = llama_init_from_model(loaded, ctxParams) else {
      llama_model_free(loaded)
      throw FlorienLlamaError.loadFailed
    }
    model = loaded
    context = ctx
    vocab = llama_model_get_vocab(loaded)
    loadedPath = path
  }

  func complete(prompt: String, maxTokens: Int) throws -> String {
    guard let context, let vocab else { throw FlorienLlamaError.loadFailed }
    llama_memory_clear(llama_get_memory(context), true)
    let tokens = tokenize(prompt, vocab: vocab)
    guard !tokens.isEmpty else { throw FlorienLlamaError.generateFailed }
    let ctxSize = Int(llama_n_ctx(context))
    let limit = min(tokens.count + max(8, maxTokens), ctxSize - 1)
    if tokens.count >= limit { throw FlorienLlamaError.generateFailed }

    var batch = llama_batch_init(512, 0, 1)
    defer { llama_batch_free(batch) }
    llama_batch_clear(&batch)
    for (index, token) in tokens.enumerated() {
      llama_batch_add(&batch, token, Int32(index), [0], index == tokens.count - 1)
    }
    if llama_decode(context, batch) != 0 {
      throw FlorienLlamaError.generateFailed
    }

    var samplerParams = llama_sampler_chain_default_params()
    let sampler = llama_sampler_chain_init(samplerParams)
    llama_sampler_chain_add(sampler, llama_sampler_init_top_k(30))
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.2))
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(1234))
    defer { llama_sampler_free(sampler) }

    var pieces = [CChar]()
    var output = ""
    var position = Int32(tokens.count)
    while Int(position) < limit {
      let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
      if llama_vocab_is_eog(vocab, token) { break }
      pieces.append(contentsOf: tokenToPiece(token, vocab: vocab))
      if let text = String(validatingUTF8: pieces + [0]) {
        output += text
        pieces.removeAll()
      }
      llama_batch_clear(&batch)
      llama_batch_add(&batch, token, position, [0], true)
      if llama_decode(context, batch) != 0 {
        throw FlorienLlamaError.generateFailed
      }
      position += 1
    }
    if !pieces.isEmpty {
      output += String(cString: pieces + [0])
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func unload() {
    if let context { llama_free(context) }
    if let model { llama_model_free(model) }
    context = nil
    model = nil
    vocab = nil
    loadedPath = nil
  }

  private func tokenize(_ text: String, vocab: OpaquePointer) -> [llama_token] {
    let utf8Count = text.utf8.count
    let capacity = utf8Count + 8
    let buffer = UnsafeMutablePointer<llama_token>.allocate(capacity: capacity)
    defer { buffer.deallocate() }
    let count = llama_tokenize(
      vocab,
      text,
      Int32(utf8Count),
      buffer,
      Int32(capacity),
      false,
      true
    )
    guard count > 0 else { return [] }
    return Array(UnsafeBufferPointer(start: buffer, count: Int(count)))
  }

  private func tokenToPiece(_ token: llama_token, vocab: OpaquePointer) -> [CChar] {
    let initial = UnsafeMutablePointer<CChar>.allocate(capacity: 16)
    initial.initialize(repeating: 0, count: 16)
    defer { initial.deallocate() }
    let written = llama_token_to_piece(vocab, token, initial, 16, 0, false)
    if written >= 0 {
      return Array(UnsafeBufferPointer(start: initial, count: Int(written)))
    }
    let needed = Int(-written)
    let larger = UnsafeMutablePointer<CChar>.allocate(capacity: needed)
    larger.initialize(repeating: 0, count: needed)
    defer { larger.deallocate() }
    let again = llama_token_to_piece(vocab, token, larger, Int32(needed), 0, false)
    return Array(UnsafeBufferPointer(start: larger, count: Int(max(0, again))))
  }
}

private func llama_batch_clear(_ batch: inout llama_batch) {
  batch.n_tokens = 0
}

private func llama_batch_add(
  _ batch: inout llama_batch,
  _ id: llama_token,
  _ pos: llama_pos,
  _ seqIds: [llama_seq_id],
  _ logits: Bool
) {
  let index = Int(batch.n_tokens)
  batch.token[index] = id
  batch.pos[index] = pos
  batch.n_seq_id[index] = Int32(seqIds.count)
  for offset in 0..<seqIds.count {
    batch.seq_id[index]![offset] = seqIds[offset]
  }
  batch.logits[index] = logits ? 1 : 0
  batch.n_tokens += 1
}

#else

final class FlorienLlamaEngine {
  static let shared = FlorienLlamaEngine()

  func load(path _: String?, nGpuLayers _: Int?) throws {
    throw FlorienLlamaError.unavailable
  }

  func complete(prompt _: String, maxTokens _: Int) throws -> String {
    throw FlorienLlamaError.unavailable
  }
}

#endif
