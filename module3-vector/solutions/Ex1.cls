/// Exercise 1 - Embeddings (slides 3-11). Three small helpers; you use them in the IRIS terminal
/// (the commands are in the Workshop Guide, Exercise 1).
Class Workshop.Exercise.Ex1 Extends %RegisteredObject
{

/// Step 1 - download the embedding model (Python, the sentence-transformers library):
/// https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2, ~90 MB, saved in /durable/hf-cache.
/// Returns the number of values in each vector it makes: 384.
ClassMethod LoadModel() As %Integer [ Language = python ]
{
    import huggingface_hub.constants
    huggingface_hub.constants.HF_HUB_OFFLINE = False   # IRIS runs offline by default; allow this download
    from sentence_transformers import SentenceTransformer
    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2", cache_folder="/durable/hf-cache")
    return model.get_embedding_dimension()
}

/// Step 2 - make an embedding: text in, a vector of 384 numbers out. One line of SQL: EMBEDDING() runs the model
/// you registered as 'workshop-minilm' (Exercise 1 step 1, in the Portal).
ClassMethod Embed(text As %String) As %Vector
{
    &sql(SELECT EMBEDDING(:text, 'workshop-minilm') INTO :vector)
    return vector
}

/// Step 3 - make a small vector by hand: Vector("1,0") is the vector (1, 0). Also one line of SQL: TO_VECTOR turns
/// the text '1,0' into a vector. FLOAT is the element type EMBEDDING() uses too - a dot product needs both vectors of one type.
ClassMethod Vector(numbers As %String) As %Vector
{
    &sql(SELECT TO_VECTOR(:numbers, FLOAT) INTO :vector)
    return vector
}

}
