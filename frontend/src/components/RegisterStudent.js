import { useState } from 'react';
import { registerStudent } from '../services/api';

const departments = ['CS', 'EE', 'ME', 'CE'];

export default function RegisterStudent() {
  const [form, setForm] = useState({ id: '', name: '', department: 'CS' });
  const [message, setMessage] = useState({ text: '', type: '' });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage({ text: '', type: '' });
    setLoading(true);
    try {
      const res = await registerStudent(form.id, form.name, form.department);
      setMessage({ text: res.data.message, type: 'success' });
      setForm({ id: '', name: '', department: 'CS' });
    } catch (err) {
      setMessage({ text: err.response?.data?.error || 'Error registering student', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <div className="card-title">
        <span className="icon icon-blue">+</span>
        Register New Student
      </div>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label className="form-label">Student ID</label>
          <input
            className="form-input"
            placeholder="e.g. S001"
            value={form.id}
            onChange={(e) => setForm({ ...form, id: e.target.value })}
            required
          />
        </div>
        <div className="form-group">
          <label className="form-label">Full Name</label>
          <input
            className="form-input"
            placeholder="e.g. Alice Kumar"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            required
          />
        </div>
        <div className="form-group">
          <label className="form-label">Department</label>
          <select
            className="form-select"
            value={form.department}
            onChange={(e) => setForm({ ...form, department: e.target.value })}
          >
            {departments.map((d) => (
              <option key={d} value={d}>{d}</option>
            ))}
          </select>
        </div>
        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? <span className="loading" /> : 'Register Student'}
        </button>
      </form>
      {message.text && (
        <div className={`alert alert-${message.type}`}>{message.text}</div>
      )}
    </div>
  );
}
