/**
 * Minimal llama.h header for FFI binding generation.
 * 
 * This is a subset of the actual llama.cpp API that covers the essential
 * functionality needed for inference. When the llama.cpp submodule is added,
 * regenerate bindings from the full header.
 * 
 * See: https://github.com/ggerganov/llama.cpp/blob/master/include/llama.h
 */

#ifndef LLAMA_H
#define LLAMA_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

//
// C interface
//
// TODO: show sample usage
//

// Forward declarations
struct llama_model;
struct llama_context;
struct llama_sampler;

typedef struct llama_model llama_model;
typedef struct llama_context llama_context;
typedef struct llama_sampler llama_sampler;

typedef int32_t llama_pos;
typedef int32_t llama_token;
typedef int32_t llama_seq_id;

// Model vocabulary type
enum llama_vocab_type {
    LLAMA_VOCAB_TYPE_NONE = 0, // For models without a vocabulary
    LLAMA_VOCAB_TYPE_SPM  = 1, // SentencePiece
    LLAMA_VOCAB_TYPE_BPE  = 2, // Byte Pair Encoding
    LLAMA_VOCAB_TYPE_WPM  = 3, // WordPiece
    LLAMA_VOCAB_TYPE_UGM  = 4, // Unigram
    LLAMA_VOCAB_TYPE_RWKV = 5, // RWKV
};

// Token types
enum llama_token_type {
    LLAMA_TOKEN_TYPE_UNDEFINED    = 0,
    LLAMA_TOKEN_TYPE_NORMAL       = 1,
    LLAMA_TOKEN_TYPE_UNKNOWN      = 2,
    LLAMA_TOKEN_TYPE_CONTROL      = 3,
    LLAMA_TOKEN_TYPE_USER_DEFINED = 4,
    LLAMA_TOKEN_TYPE_UNUSED       = 5,
    LLAMA_TOKEN_TYPE_BYTE         = 6,
};

// Model file types
enum llama_ftype {
    LLAMA_FTYPE_ALL_F32              = 0,
    LLAMA_FTYPE_MOSTLY_F16           = 1,
    LLAMA_FTYPE_MOSTLY_Q4_0          = 2,
    LLAMA_FTYPE_MOSTLY_Q4_1          = 3,
    LLAMA_FTYPE_MOSTLY_Q8_0          = 7,
    // ... more quantization types
};

// Split mode
enum llama_split_mode {
    LLAMA_SPLIT_MODE_NONE  = 0, // single GPU
    LLAMA_SPLIT_MODE_LAYER = 1, // split layers across GPUs
    LLAMA_SPLIT_MODE_ROW   = 2, // split rows across GPUs
};

// RoPE scaling type
enum llama_rope_scaling_type {
    LLAMA_ROPE_SCALING_TYPE_UNSPECIFIED = -1,
    LLAMA_ROPE_SCALING_TYPE_NONE        = 0,
    LLAMA_ROPE_SCALING_TYPE_LINEAR      = 1,
    LLAMA_ROPE_SCALING_TYPE_YARN        = 2,
    LLAMA_ROPE_SCALING_TYPE_MAX_VALUE   = LLAMA_ROPE_SCALING_TYPE_YARN,
};

// Pooling type
enum llama_pooling_type {
    LLAMA_POOLING_TYPE_UNSPECIFIED = -1,
    LLAMA_POOLING_TYPE_NONE = 0,
    LLAMA_POOLING_TYPE_MEAN = 1,
    LLAMA_POOLING_TYPE_CLS  = 2,
    LLAMA_POOLING_TYPE_LAST = 3,
};

// Attention type
enum llama_attention_type {
    LLAMA_ATTENTION_TYPE_UNSPECIFIED = -1,
    LLAMA_ATTENTION_TYPE_CAUSAL      = 0,
    LLAMA_ATTENTION_TYPE_NON_CAUSAL  = 1,
};

// Model parameters
struct llama_model_params {
    int32_t n_gpu_layers;      // number of layers to store in VRAM
    enum llama_split_mode split_mode; // how to split the model across GPUs
    int32_t main_gpu;          // main GPU to use
    const float * tensor_split; // how to split layers across GPUs (size: 128)
    
    // Progress callback
    void * progress_callback_user_data;
    
    // Override key-value pairs
    const void * kv_overrides;
    
    // Model vocabulary type override
    bool vocab_only;
    bool use_mmap;
    bool use_mlock;
    bool check_tensors;
};

// Context parameters
struct llama_context_params {
    uint32_t n_ctx;            // text context, 0 = from model
    uint32_t n_batch;          // logical maximum batch size
    uint32_t n_ubatch;         // physical maximum batch size
    uint32_t n_seq_max;        // max number of sequences
    int32_t  n_threads;        // number of threads for generation
    int32_t  n_threads_batch;  // number of threads for batch processing
    
    enum llama_rope_scaling_type rope_scaling_type;
    enum llama_pooling_type      pooling_type;
    enum llama_attention_type    attention_type;
    
    float rope_freq_base;
    float rope_freq_scale;
    float yarn_ext_factor;
    float yarn_attn_factor;
    float yarn_beta_fast;
    float yarn_beta_slow;
    uint32_t yarn_orig_ctx;
    float defrag_thold;
    
    // Abort callback
    void * abort_callback;
    void * abort_callback_data;
    
    // Type of quantization
    int type_k;
    int type_v;
    
    bool logits_all;
    bool embeddings;
    bool offload_kqv;
    bool flash_attn;
    bool no_perf;
};

// Model quantization parameters
struct llama_model_quantize_params {
    int32_t nthread;
    enum llama_ftype ftype;
    int32_t output_tensor_type;
    int32_t token_embedding_type;
    bool allow_requantize;
    bool quantize_output_tensor;
    bool only_copy;
    bool pure;
    bool keep_split;
    void * imatrix;
    void * kv_overrides;
};

// Batch for submitting tokens
struct llama_batch {
    int32_t n_tokens;
    
    llama_token  * token;
    float        * embd;
    llama_pos    * pos;
    int32_t      * n_seq_id;
    llama_seq_id ** seq_id;
    int8_t       * logits;
};

// Token data
typedef struct llama_token_data {
    llama_token id;
    float logit;
    float p;
} llama_token_data;

// Token data array
typedef struct llama_token_data_array {
    llama_token_data * data;
    size_t size;
    int64_t selected;
    bool sorted;
} llama_token_data_array;

//
// Library initialization
//

// Initialize the llama backend
void llama_backend_init(void);

// Cleanup the llama backend - call once at the end
void llama_backend_free(void);

//
// Model loading
//

// Get default model parameters
struct llama_model_params llama_model_default_params(void);

// Load a model from file
llama_model * llama_load_model_from_file(
    const char * path_model,
    struct llama_model_params params);

// Free a model
void llama_free_model(llama_model * model);

//
// Context management
//

// Get default context parameters
struct llama_context_params llama_context_default_params(void);

// Create a context with a model
llama_context * llama_new_context_with_model(
    llama_model * model,
    struct llama_context_params params);

// Free a context
void llama_free(llama_context * ctx);

//
// Model properties
//

// Get vocab size
int32_t llama_n_vocab(const llama_model * model);

// Get context size
int32_t llama_n_ctx_train(const llama_model * model);

// Get embedding size
int32_t llama_n_embd(const llama_model * model);

// Get vocabulary type
enum llama_vocab_type llama_vocab_type(const llama_model * model);

//
// Context properties
//

// Get context size
int32_t llama_n_ctx(const llama_context * ctx);

// Get batch size
int32_t llama_n_batch(const llama_context * ctx);

//
// Special tokens
//

// Beginning of sentence token
llama_token llama_token_bos(const llama_model * model);

// End of sentence token
llama_token llama_token_eos(const llama_model * model);

// Classification/separation token
llama_token llama_token_cls(const llama_model * model);

// Sentence separator token
llama_token llama_token_sep(const llama_model * model);

// Newline token
llama_token llama_token_nl(const llama_model * model);

// Padding token
llama_token llama_token_pad(const llama_model * model);

// Prefix token (for infill)
llama_token llama_token_prefix(const llama_model * model);

// Middle token (for infill)
llama_token llama_token_middle(const llama_model * model);

// Suffix token (for infill)
llama_token llama_token_suffix(const llama_model * model);

// End of text token (for infill)
llama_token llama_token_eot(const llama_model * model);

// Check if token is EOG (end of generation)
bool llama_token_is_eog(const llama_model * model, llama_token token);

// Check if token is control
bool llama_token_is_control(const llama_model * model, llama_token token);

//
// Tokenization
//

// Convert text to tokens
// Returns the number of tokens, negative on error
int32_t llama_tokenize(
    const llama_model * model,
    const char * text,
    int32_t text_len,
    llama_token * tokens,
    int32_t n_tokens_max,
    bool add_special,
    bool parse_special);

// Convert token to text piece
// Returns the number of characters, negative on error
int32_t llama_token_to_piece(
    const llama_model * model,
    llama_token token,
    char * buf,
    int32_t length,
    int32_t lstrip,
    bool special);

// Detokenize - convert tokens back to text
int32_t llama_detokenize(
    const llama_model * model,
    const llama_token * tokens,
    int32_t n_tokens,
    char * text,
    int32_t text_len_max,
    bool remove_special,
    bool unparse_special);

//
// Batch operations
//

// Initialize a batch (deprecated, use llama_batch_get_one or manual allocation)
struct llama_batch llama_batch_init(int32_t n_tokens, int32_t embd, int32_t n_seq_max);

// Free batch memory
void llama_batch_free(struct llama_batch batch);

// Get a batch for a single sequence of tokens
struct llama_batch llama_batch_get_one(
    llama_token * tokens,
    int32_t n_tokens,
    llama_pos pos_0,
    llama_seq_id seq_id);

//
// Decode (inference)
//

// Run the model on the batch
// Returns 0 on success, 1 if could not find KV slot, < 0 on error
int32_t llama_decode(llama_context * ctx, struct llama_batch batch);

//
// Logits access
//

// Get logits for all tokens (requires logits_all = true)
float * llama_get_logits(llama_context * ctx);

// Get logits for the i-th token
float * llama_get_logits_ith(llama_context * ctx, int32_t i);

//
// KV cache management
//

// Clear the KV cache
void llama_kv_cache_clear(llama_context * ctx);

// Remove tokens from KV cache
// seq_id < 0 removes from all sequences
// p0 < 0 removes from start
// p1 < 0 removes to end
bool llama_kv_cache_seq_rm(
    llama_context * ctx,
    llama_seq_id seq_id,
    llama_pos p0,
    llama_pos p1);

// Copy tokens from one sequence to another
void llama_kv_cache_seq_cp(
    llama_context * ctx,
    llama_seq_id seq_id_src,
    llama_seq_id seq_id_dst,
    llama_pos p0,
    llama_pos p1);

// Shift positions in KV cache
void llama_kv_cache_seq_add(
    llama_context * ctx,
    llama_seq_id seq_id,
    llama_pos p0,
    llama_pos p1,
    llama_pos delta);

//
// Sampling
//

// Sampler chain
llama_sampler * llama_sampler_chain_init(void * params);
void llama_sampler_chain_add(llama_sampler * chain, llama_sampler * smpl);
void llama_sampler_free(llama_sampler * smpl);
void llama_sampler_reset(llama_sampler * smpl);
llama_token llama_sampler_sample(llama_sampler * smpl, llama_context * ctx, int32_t idx);

// Create samplers
llama_sampler * llama_sampler_init_greedy(void);
llama_sampler * llama_sampler_init_dist(uint32_t seed);
llama_sampler * llama_sampler_init_top_k(int32_t k);
llama_sampler * llama_sampler_init_top_p(float p, size_t min_keep);
llama_sampler * llama_sampler_init_min_p(float p, size_t min_keep);
llama_sampler * llama_sampler_init_temp(float t);
llama_sampler * llama_sampler_init_temp_ext(float t, float delta, float exponent);
llama_sampler * llama_sampler_init_penalties(
    int32_t n_vocab,
    llama_token special_eos_id,
    llama_token linefeed_id,
    int32_t penalty_last_n,
    float penalty_repeat,
    float penalty_freq,
    float penalty_present,
    bool penalize_nl,
    bool ignore_eos);

//
// Timing
//

// Performance timing info
void llama_perf_context_print(const llama_context * ctx);
void llama_perf_context_reset(llama_context * ctx);

//
// Misc
//

// Print system info
const char * llama_print_system_info(void);

// Set log callback
void llama_log_set(void * log_callback, void * user_data);

// Get number of physical CPU cores
int32_t llama_max_devices(void);

#ifdef __cplusplus
}
#endif

#endif // LLAMA_H

