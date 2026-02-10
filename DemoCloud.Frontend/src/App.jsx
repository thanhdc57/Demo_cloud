import { useState, useEffect } from 'react'
import './App.css'

const API_URL = '/api/products';

function App() {
  const [products, setProducts] = useState([]);
  const [newProduct, setNewProduct] = useState({ name: '', price: '', description: '' });
  const [editingProduct, setEditingProduct] = useState(null);

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      const response = await fetch(API_URL);
      if (response.ok) {
        const data = await response.json();
        setProducts(data);
      } else {
        console.error('Failed to fetch products');
      }
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  };

  const handleCreate = async (e) => {
    e.preventDefault();
    try {
      const response = await fetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newProduct.name,
          price: parseFloat(newProduct.price),
          description: newProduct.description
        }),
      });
      if (response.ok) {
        setNewProduct({ name: '', price: '', description: '' });
        fetchProducts();
      }
    } catch (error) {
      console.error('Error creating product:', error);
    }
  };

  const handleUpdate = async (e) => {
    e.preventDefault();
    if (!editingProduct) return;

    try {
      const response = await fetch(`${API_URL}/${editingProduct.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: editingProduct.id,
          name: editingProduct.name,
          price: parseFloat(editingProduct.price),
          description: editingProduct.description
        }),
      });

      if (response.ok) {
        setEditingProduct(null);
        fetchProducts();
      }
    } catch (error) {
      console.error('Error updating product:', error);
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this product?')) return;
    try {
      const response = await fetch(`${API_URL}/${id}`, {
        method: 'DELETE',
      });
      if (response.ok) {
        fetchProducts();
      }
    } catch (error) {
      console.error('Error deleting product:', error);
    }
  };

  return (
    <div className="container">
      <h1>Product Management</h1>

      <div className="form-section">
        <h2>{editingProduct ? 'Edit Product' : 'Add New Product'}</h2>
        <form onSubmit={editingProduct ? handleUpdate : handleCreate}>
          <input
            type="text"
            placeholder="Name"
            value={editingProduct ? editingProduct.name : newProduct.name}
            onChange={(e) => editingProduct
              ? setEditingProduct({ ...editingProduct, name: e.target.value })
              : setNewProduct({ ...newProduct, name: e.target.value })}
            required
          />
          <input
            type="number"
            placeholder="Price"
            value={editingProduct ? editingProduct.price : newProduct.price}
            onChange={(e) => editingProduct
              ? setEditingProduct({ ...editingProduct, price: e.target.value })
              : setNewProduct({ ...newProduct, price: e.target.value })}
            required
          />
          <textarea
            placeholder="Description"
            value={editingProduct ? editingProduct.description : newProduct.description}
            onChange={(e) => editingProduct
              ? setEditingProduct({ ...editingProduct, description: e.target.value })
              : setNewProduct({ ...newProduct, description: e.target.value })}
          />
          <button type="submit">{editingProduct ? 'Update' : 'Add'}</button>
          {editingProduct && (
            <button type="button" onClick={() => setEditingProduct(null)}>Cancel</button>
          )}
        </form>
      </div>

      <div className="list-section">
        <h2>Product List</h2>
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Price</th>
              <th>Description</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {products.map(product => (
              <tr key={product.id}>
                <td>{product.id}</td>
                <td>{product.name}</td>
                <td>${product.price}</td>
                <td>{product.description}</td>
                <td>
                  <button onClick={() => setEditingProduct(product)}>Edit</button>
                  <button onClick={() => handleDelete(product.id)}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default App
