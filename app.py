import os
import google.generativeai as genai
from flask import Flask, render_template, request, jsonify
import chromadb
from sentence_transformers import SentenceTransformer
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# Configure Gemini
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
genai.configure(api_key=GEMINI_API_KEY)
# We will use gemini-3.5-flash as the lightweight/fast model for RAG
try:
    llm_model = genai.GenerativeModel('gemini-3.5-flash')
except Exception as e:
    print('Failed to init gemini model:', e)
    llm_model = None

# Initialize Embeddings and Chroma
try:
    print('Loading embedding model...')
    embedding_model = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')
    print('Loading ChromaDB...')
    chroma_client = chromadb.PersistentClient(path='./chroma_db')
    collection = chroma_client.get_collection(name='gahar_handbook')
except Exception as e:
    print('Warning: Failed to load embeddings or ChromaDB. Did you run ingest.py?', e)
    embedding_model = None
    collection = None

@app.route('/')
def index():
    return render_template('chat.html')

@app.route('/api/chat', methods=['POST'])
def chat():
    if not llm_model or not embedding_model or not collection:
        return jsonify({'error': 'Backend not fully initialized. Check embeddings, DB, or API keys.'}), 500

    data = request.json
    user_message = data.get('message', '')
    
    if not user_message:
        return jsonify({'error': 'No message provided'}), 400

    try:
        # Embed user query
        query_embedding = embedding_model.encode([user_message]).tolist()
        
        # Query ChromaDB
        results = collection.query(
            query_embeddings=query_embedding,
            n_results=5
        )
        
        # Construct Context
        context_chunks = results['documents'][0]
        context_text = '\n\n'.join(context_chunks)
        
        # Create Prompt
        prompt = f'''You are a helpful assistant for the IHIS web application. 
Use the following context from the GAHAR Hospital Accreditation Standards 2025 Edition to answer the user's question. 
If the answer is not contained in the context, say so. Answer in the same language as the user's question (English or Arabic).
Please format your response using Markdown. Use bold headers, bullet points, and nice spacing to make it easy to read.

Context:
{context_text}

User Question: {user_message}

Answer:'''

        # Call LLM
        response = llm_model.generate_content(prompt)
        
        return jsonify({'response': response.text})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5000)
