import React, { useState } from 'react';
import { Calendar } from 'lucide-react';
import PageHeader from '../components/PageHeader';
import Modal from '../components/Modal';
import Toast, { ToastType } from '../components/Toast';
import { LeaveRequest } from '../services/leaveRequestsService';

const LeaveCalendarPage: React.FC = () => {
    const [view, setView] = useState<'month' | 'week'>('month');
    const [departmentFilter, setDepartmentFilter] = useState<string>('');
    const [selectedLeave, setSelectedLeave] = useState<LeaveRequest | null>(null);
    const [toast, setToast] = useState<{ message: string; type: ToastType } | null>(null);

    // TODO: Integrate with @so360/design-system LeaveCalendar component when available
    // For now, showing placeholder

    const handleLeaveClick = (leave: LeaveRequest) => {
        setSelectedLeave(leave);
    };

    return (
        <div className="p-6 space-y-5">
            <PageHeader
                title="Leave Calendar"
                subtitle="Visual overview of team availability"
            />

            {/* View Controls */}
            <div className="flex items-center gap-3">
                <div className="flex items-center gap-2 border border-slate-700 rounded-lg p-1">
                    <button
                        onClick={() => setView('month')}
                        className={`px-3 py-1.5 text-sm font-medium rounded transition-colors ${
                            view === 'month'
                                ? 'bg-teal-600 text-white'
                                : 'text-slate-400 hover:text-white'
                        }`}
                    >
                        Month
                    </button>
                    <button
                        onClick={() => setView('week')}
                        className={`px-3 py-1.5 text-sm font-medium rounded transition-colors ${
                            view === 'week'
                                ? 'bg-teal-600 text-white'
                                : 'text-slate-400 hover:text-white'
                        }`}
                    >
                        Week
                    </button>
                </div>

                <select
                    value={departmentFilter}
                    onChange={(e) => setDepartmentFilter(e.target.value)}
                    className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:outline-none focus:border-teal-500"
                >
                    <option value="">All Departments</option>
                    <option value="engineering">Engineering</option>
                    <option value="sales">Sales</option>
                    <option value="marketing">Marketing</option>
                </select>
            </div>

            {/* Calendar Placeholder */}
            <div className="bg-slate-900 border border-slate-800 rounded-xl p-8">
                <div className="text-center py-12">
                    <Calendar className="mx-auto h-16 w-16 text-slate-600 mb-4" />
                    <h3 className="text-lg font-medium text-white mb-2">Leave Calendar</h3>
                    <p className="text-sm text-slate-400 mb-4">
                        Calendar view will be integrated with @so360/design-system LeaveCalendar component
                    </p>
                    <div className="text-xs text-slate-500">
                        <p>View: {view}</p>
                        {departmentFilter && <p>Department: {departmentFilter}</p>}
                    </div>
                </div>

                {/* Calendar grid placeholder */}
                <div className="grid grid-cols-7 gap-2 mt-8">
                    {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
                        <div key={day} className="text-center text-xs font-medium text-slate-400 uppercase py-2">
                            {day}
                        </div>
                    ))}
                    {Array.from({ length: 35 }).map((_, i) => (
                        <div
                            key={i}
                            className="aspect-square bg-slate-800/30 rounded-lg border border-slate-800 hover:border-slate-700 transition-colors cursor-pointer"
                        >
                            <div className="p-2 text-xs text-slate-500">
                                {((i % 31) + 1)}
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Leave Details Modal */}
            {selectedLeave && (
                <Modal
                    isOpen={!!selectedLeave}
                    onClose={() => setSelectedLeave(null)}
                    title="Leave Details"
                >
                    <div className="space-y-4">
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Person</label>
                            <p className="text-sm text-white">{selectedLeave.person?.full_name}</p>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Leave Type</label>
                            <p className="text-sm text-white">{selectedLeave.leave_type?.name}</p>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <label className="block text-xs text-slate-400 mb-1">Start Date</label>
                                <p className="text-sm text-white">
                                    {new Date(selectedLeave.start_date).toLocaleDateString()}
                                </p>
                            </div>
                            <div>
                                <label className="block text-xs text-slate-400 mb-1">End Date</label>
                                <p className="text-sm text-white">
                                    {new Date(selectedLeave.end_date).toLocaleDateString()}
                                </p>
                            </div>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Total Days</label>
                            <p className="text-sm text-white">{selectedLeave.total_days}</p>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Status</label>
                            <p className="text-sm text-white capitalize">{selectedLeave.status}</p>
                        </div>
                        {selectedLeave.reason && (
                            <div>
                                <label className="block text-xs text-slate-400 mb-1">Reason</label>
                                <p className="text-sm text-white">{selectedLeave.reason}</p>
                            </div>
                        )}
                    </div>
                </Modal>
            )}

            {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
        </div>
    );
};

export default LeaveCalendarPage;
