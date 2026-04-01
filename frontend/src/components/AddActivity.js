import { useState } from 'react';
import { addActivity } from '../services/api';

export default function AddActivity() {
  const [form, setForm] = useState({ id: '', type: 'fee', details: '' });
  const [message, setMessage] = useState({ text: '', type: '' });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setMessage({ text: '', type: '' });
    setLoading(true);
    try {
      const res = await addActivity(form.id, form.type, form.details);
      setMessage({ text: res.data.message, type: 'success' });
      setForm({ id: '', type: 'fee', details: '' });
    } catch (err) {
      setMessage({ text: err.response?.data?.error || 'Error adding activity', type: 'error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <div className="card-title">
        <span className="icon icon-green">~</span>
        Add Activity
      </div>
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label className="form-label">Student ID</label>
          <input
            className="form-input"
            placeholder="e.g. STU001"
            value={form.id}
            onChange={(e) => setForm({ ...form, id: e.target.value })}
            required
          />
        </div>
        <div className="form-group">
          <label className="form-label">Activity Type</label>
          <select
            className="form-select"
            value={form.type}
            onChange={(e) => setForm({ ...form, type: e.target.value })}
          >
            <option value="fee">Fee Payment</option>
            <option value="library">Library Transaction</option>
            <option value="exam">Exam Registration</option>
          </select>
        </div>
        <div className="form-group">
          <label className="form-label">Details</label>
          <input
            className="form-input"
            placeholder="e.g. Tuition payment - Semester 1"
            value={form.details}
            onChange={(e) => setForm({ ...form, details: e.target.value })}
            required
          />
        </div>
        <button type="submit" className="btn btn-primary" disabled={loading}>
          {loading ? <span className="loading" /> : 'Add Activity'}
        </button>
      </form>
      {message.text && (
        <div className={`alert alert-${message.type}`}>{message.text}</div>
      )}
    </div>
  );
}
