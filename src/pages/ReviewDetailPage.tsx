import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Star } from 'lucide-react';
import PageHeader from '../components/PageHeader';
import StatusBadge from '../components/StatusBadge';
import Toast, { ToastType } from '../components/Toast';
import { performanceReviewsApi, PerformanceReview } from '../services/performanceReviewsService';

const ReviewDetailPage: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const [review, setReview] = useState<PerformanceReview | null>(null);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState<'self' | 'manager' | 'overall'>('self');
    const [toast, setToast] = useState<{ message: string; type: ToastType } | null>(null);

    useEffect(() => {
        if (id) loadReview(id);
    }, [id]);

    const loadReview = async (reviewId: string) => {
        try {
            setLoading(true);
            const data = await performanceReviewsApi.getById(reviewId);
            setReview(data);
        } catch (error) {
            console.error('Failed to load review:', error);
            setToast({ message: 'Failed to load review', type: 'error' });
        } finally {
            setLoading(false);
        }
    };

    const handleSubmitSelfReview = async () => {
        if (!review) return;

        try {
            // TODO: Collect form data from ReviewForm component
            const reviewData = {};
            await performanceReviewsApi.submitSelfReview(review.id, reviewData);
            setToast({ message: 'Self review submitted successfully', type: 'success' });
            if (id) loadReview(id);
        } catch (error) {
            setToast({ message: 'Failed to submit self review', type: 'error' });
        }
    };

    const handleSubmitManagerReview = async () => {
        if (!review) return;

        try {
            // TODO: Collect form data from ReviewForm component
            const reviewData = {};
            const overallRating = 4.5; // TODO: Calculate from form
            await performanceReviewsApi.submitManagerReview(review.id, reviewData, overallRating);
            setToast({ message: 'Manager review submitted successfully', type: 'success' });
            if (id) loadReview(id);
        } catch (error) {
            setToast({ message: 'Failed to submit manager review', type: 'error' });
        }
    };

    const handleCompleteReview = async () => {
        if (!review) return;

        try {
            await performanceReviewsApi.complete(review.id);
            setToast({ message: 'Review completed successfully', type: 'success' });
            if (id) loadReview(id);
        } catch (error) {
            setToast({ message: 'Failed to complete review', type: 'error' });
        }
    };

    const getStatusColor = (status: string) => {
        switch (status) {
            case 'draft': return 'bg-slate-600';
            case 'self_review_pending': return 'bg-blue-600';
            case 'manager_review_pending': return 'bg-yellow-600';
            case 'completed': return 'bg-green-600';
            default: return 'bg-slate-600';
        }
    };

    if (loading) {
        return (
            <div className="p-6">
                <div className="h-20 bg-slate-800/50 rounded-xl animate-pulse mb-5" />
                <div className="h-96 bg-slate-800/50 rounded-xl animate-pulse" />
            </div>
        );
    }

    if (!review) {
        return (
            <div className="p-6">
                <p className="text-slate-400">Review not found</p>
            </div>
        );
    }

    return (
        <div className="p-6 space-y-5">
            {/* Header with back button */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/reviews')}
                    className="p-2 hover:bg-slate-800 rounded-lg transition-colors"
                >
                    <ArrowLeft size={20} className="text-slate-400" />
                </button>
                <PageHeader
                    title={`${review.person?.full_name} - ${review.template?.name}`}
                    subtitle={`Review Period: ${new Date(review.review_period_start).toLocaleDateString()} - ${new Date(review.review_period_end).toLocaleDateString()}`}
                />
            </div>

            {/* Review Info Card */}
            <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
                <div className="grid grid-cols-4 gap-6">
                    <div>
                        <label className="block text-xs text-slate-400 mb-1">Reviewer</label>
                        <p className="text-sm text-white">{review.reviewer?.full_name}</p>
                    </div>
                    <div>
                        <label className="block text-xs text-slate-400 mb-1">Status</label>
                        <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full text-white ${getStatusColor(review.status)}`}>
                            {review.status.replace('_', ' ')}
                        </span>
                    </div>
                    <div>
                        <label className="block text-xs text-slate-400 mb-1">Self Review Deadline</label>
                        <p className="text-sm text-white">
                            {review.self_review_deadline
                                ? new Date(review.self_review_deadline).toLocaleDateString()
                                : '-'}
                        </p>
                    </div>
                    <div>
                        <label className="block text-xs text-slate-400 mb-1">Manager Review Deadline</label>
                        <p className="text-sm text-white">
                            {review.manager_review_deadline
                                ? new Date(review.manager_review_deadline).toLocaleDateString()
                                : '-'}
                        </p>
                    </div>
                </div>

                {review.overall_rating && (
                    <div className="mt-6 pt-6 border-t border-slate-800">
                        <label className="block text-xs text-slate-400 mb-2">Overall Rating</label>
                        <div className="flex items-center gap-2">
                            {Array.from({ length: 5 }).map((_, i) => (
                                <Star
                                    key={i}
                                    size={20}
                                    className={i < Math.round(review.overall_rating!) ? 'fill-yellow-500 text-yellow-500' : 'text-slate-600'}
                                />
                            ))}
                            <span className="text-lg font-medium text-white ml-2">{review.overall_rating.toFixed(1)}</span>
                        </div>
                    </div>
                )}
            </div>

            {/* Tabs */}
            <div className="flex items-center gap-2 border-b border-slate-800">
                <button
                    onClick={() => setActiveTab('self')}
                    className={`px-4 py-2 text-sm font-medium transition-colors ${
                        activeTab === 'self'
                            ? 'text-teal-400 border-b-2 border-teal-400'
                            : 'text-slate-400 hover:text-slate-300'
                    }`}
                >
                    Self Review
                </button>
                <button
                    onClick={() => setActiveTab('manager')}
                    className={`px-4 py-2 text-sm font-medium transition-colors ${
                        activeTab === 'manager'
                            ? 'text-teal-400 border-b-2 border-teal-400'
                            : 'text-slate-400 hover:text-slate-300'
                    }`}
                >
                    Manager Review
                </button>
                <button
                    onClick={() => setActiveTab('overall')}
                    className={`px-4 py-2 text-sm font-medium transition-colors ${
                        activeTab === 'overall'
                            ? 'text-teal-400 border-b-2 border-teal-400'
                            : 'text-slate-400 hover:text-slate-300'
                    }`}
                >
                    Overall
                </button>
            </div>

            {/* Review Form Placeholder */}
            <div className="bg-slate-900 border border-slate-800 rounded-xl p-8">
                <div className="text-center py-12">
                    <h3 className="text-lg font-medium text-white mb-2">
                        {activeTab === 'self' ? 'Self Review' : activeTab === 'manager' ? 'Manager Review' : 'Overall Review'}
                    </h3>
                    <p className="text-sm text-slate-400 mb-4">
                        ReviewForm component will be integrated from @so360/design-system
                    </p>
                    <div className="text-xs text-slate-500">
                        <p>Template: {review.template?.name}</p>
                        <p>Status: {review.status}</p>
                        {activeTab === 'self' && review.self_review_submitted_at && (
                            <p className="text-green-400 mt-2">Self review submitted on {new Date(review.self_review_submitted_at).toLocaleDateString()}</p>
                        )}
                        {activeTab === 'manager' && review.manager_review_submitted_at && (
                            <p className="text-green-400 mt-2">Manager review submitted on {new Date(review.manager_review_submitted_at).toLocaleDateString()}</p>
                        )}
                    </div>
                </div>
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end gap-3">
                {review.status === 'self_review_pending' && (
                    <button
                        onClick={handleSubmitSelfReview}
                        className="px-4 py-2 bg-teal-600 hover:bg-teal-500 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                        Submit Self Review
                    </button>
                )}
                {review.status === 'manager_review_pending' && (
                    <button
                        onClick={handleSubmitManagerReview}
                        className="px-4 py-2 bg-teal-600 hover:bg-teal-500 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                        Submit Manager Review
                    </button>
                )}
                {review.status === 'manager_review_pending' && (
                    <button
                        onClick={handleCompleteReview}
                        className="px-4 py-2 bg-green-600 hover:bg-green-500 text-white text-sm font-medium rounded-lg transition-colors"
                    >
                        Complete Review
                    </button>
                )}
            </div>

            {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
        </div>
    );
};

export default ReviewDetailPage;
