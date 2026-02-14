import React, { useState } from 'react';
import { Download, Upload, FileDown, AlertCircle, CheckCircle } from 'lucide-react';
import PageHeader from '../components/PageHeader';
import Toast, { ToastType } from '../components/Toast';
import { peopleApi } from '../services/peopleService';

const ImportExportPage: React.FC = () => {
    const [exportFormat, setExportFormat] = useState<'csv' | 'excel'>('csv');
    const [statusFilter, setStatusFilter] = useState<string>('');
    const [typeFilter, setTypeFilter] = useState<string>('');
    const [departmentFilter, setDepartmentFilter] = useState<string>('');
    const [importFile, setImportFile] = useState<File | null>(null);
    const [validateOnly, setValidateOnly] = useState(true);
    const [validationResults, setValidationResults] = useState<{
        success: number;
        errors: Array<{ row: number; field: string; message: string }>;
    } | null>(null);
    const [toast, setToast] = useState<{ message: string; type: ToastType } | null>(null);

    const handleExport = async () => {
        try {
            // TODO: Implement actual export API call
            // const params = {
            //     format: exportFormat,
            //     status: statusFilter || undefined,
            //     type: typeFilter || undefined,
            //     department: departmentFilter || undefined,
            // };
            // const blob = await peopleApi.export(params);
            // downloadFile(blob, `people-export.${exportFormat}`);

            setToast({ message: `Export as ${exportFormat.toUpperCase()} (Not yet implemented)`, type: 'success' });
        } catch (error) {
            setToast({ message: 'Failed to export people', type: 'error' });
        }
    };

    const handleDownloadTemplate = async () => {
        try {
            // TODO: Implement actual template download
            setToast({ message: 'Download template (Not yet implemented)', type: 'success' });
        } catch (error) {
            setToast({ message: 'Failed to download template', type: 'error' });
        }
    };

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (file) {
            setImportFile(file);
            setValidationResults(null);
        }
    };

    const handleImport = async () => {
        if (!importFile) return;

        try {
            // TODO: Implement actual import API call
            // const formData = new FormData();
            // formData.append('file', importFile);
            // formData.append('validate_only', validateOnly.toString());
            // const result = await peopleApi.import(formData);

            // Mock validation results
            const mockResults = {
                success: 42,
                errors: [
                    { row: 5, field: 'email', message: 'Invalid email format' },
                    { row: 12, field: 'cost_rate', message: 'Cost rate must be a number' },
                    { row: 18, field: 'full_name', message: 'Full name is required' },
                ],
            };

            setValidationResults(mockResults);

            if (mockResults.errors.length === 0) {
                setToast({
                    message: validateOnly
                        ? `Validation successful! ${mockResults.success} records are valid.`
                        : `Import successful! ${mockResults.success} people imported.`,
                    type: 'success',
                });
            } else {
                setToast({
                    message: `Validation found ${mockResults.errors.length} errors.`,
                    type: 'error',
                });
            }
        } catch (error) {
            setToast({ message: 'Failed to import people', type: 'error' });
        }
    };

    return (
        <div className="p-6 space-y-5">
            <PageHeader
                title="Import/Export"
                subtitle="Bulk operations for people data"
            />

            {/* Export Section */}
            <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
                <div className="flex items-center gap-2 mb-4">
                    <Download size={20} className="text-teal-400" />
                    <h2 className="text-lg font-medium text-white">Export People</h2>
                </div>

                <div className="space-y-4">
                    <div className="grid grid-cols-4 gap-4">
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Format</label>
                            <select
                                value={exportFormat}
                                onChange={(e) => setExportFormat(e.target.value as 'csv' | 'excel')}
                                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:outline-none focus:border-teal-500"
                            >
                                <option value="csv">CSV</option>
                                <option value="excel">Excel</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Status</label>
                            <select
                                value={statusFilter}
                                onChange={(e) => setStatusFilter(e.target.value)}
                                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:outline-none focus:border-teal-500"
                            >
                                <option value="">All Statuses</option>
                                <option value="active">Active</option>
                                <option value="inactive">Inactive</option>
                                <option value="on_leave">On Leave</option>
                                <option value="terminated">Terminated</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Type</label>
                            <select
                                value={typeFilter}
                                onChange={(e) => setTypeFilter(e.target.value)}
                                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:outline-none focus:border-teal-500"
                            >
                                <option value="">All Types</option>
                                <option value="employee">Employee</option>
                                <option value="contractor">Contractor</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-xs text-slate-400 mb-1">Department</label>
                            <select
                                value={departmentFilter}
                                onChange={(e) => setDepartmentFilter(e.target.value)}
                                className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white focus:outline-none focus:border-teal-500"
                            >
                                <option value="">All Departments</option>
                                <option value="engineering">Engineering</option>
                                <option value="sales">Sales</option>
                                <option value="marketing">Marketing</option>
                            </select>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        <button
                            onClick={handleExport}
                            className="flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-500 text-white text-sm font-medium rounded-lg transition-colors"
                        >
                            <Download size={16} />
                            Export People
                        </button>
                        <button
                            onClick={handleDownloadTemplate}
                            className="flex items-center gap-2 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white text-sm font-medium rounded-lg transition-colors"
                        >
                            <FileDown size={16} />
                            Download Template
                        </button>
                    </div>
                </div>
            </div>

            {/* Import Section */}
            <div className="bg-slate-900 border border-slate-800 rounded-xl p-6">
                <div className="flex items-center gap-2 mb-4">
                    <Upload size={20} className="text-teal-400" />
                    <h2 className="text-lg font-medium text-white">Import People</h2>
                </div>

                <div className="space-y-4">
                    {/* File Upload */}
                    <div>
                        <label className="block text-xs text-slate-400 mb-2">Upload File</label>
                        <div className="border-2 border-dashed border-slate-700 rounded-lg p-8 text-center hover:border-slate-600 transition-colors">
                            <input
                                type="file"
                                accept=".csv,.xlsx,.xls"
                                onChange={handleFileChange}
                                className="hidden"
                                id="file-upload"
                            />
                            <label
                                htmlFor="file-upload"
                                className="cursor-pointer flex flex-col items-center"
                            >
                                <Upload className="h-12 w-12 text-slate-600 mb-3" />
                                <p className="text-sm text-slate-300 mb-1">
                                    {importFile ? importFile.name : 'Click to browse or drag and drop'}
                                </p>
                                <p className="text-xs text-slate-500">
                                    Supports CSV and Excel files
                                </p>
                            </label>
                        </div>
                    </div>

                    {/* Validate Only Checkbox */}
                    <label className="flex items-center gap-2">
                        <input
                            type="checkbox"
                            checked={validateOnly}
                            onChange={(e) => setValidateOnly(e.target.checked)}
                            className="w-4 h-4 rounded border-slate-700 bg-slate-800 text-teal-600 focus:ring-teal-500"
                        />
                        <span className="text-sm text-slate-300">Validate Only (Don't import yet)</span>
                    </label>

                    {/* Import Button */}
                    <button
                        onClick={handleImport}
                        disabled={!importFile}
                        className="flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-500 text-white text-sm font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        <Upload size={16} />
                        {validateOnly ? 'Validate' : 'Import'}
                    </button>

                    {/* Validation Results */}
                    {validationResults && (
                        <div className="mt-6 space-y-4">
                            {/* Success Count */}
                            {validationResults.success > 0 && (
                                <div className="bg-green-900/20 border border-green-800 rounded-lg p-4">
                                    <div className="flex items-center gap-2">
                                        <CheckCircle className="text-green-400" size={20} />
                                        <p className="text-sm font-medium text-green-400">
                                            {validationResults.success} records validated successfully
                                        </p>
                                    </div>
                                </div>
                            )}

                            {/* Errors */}
                            {validationResults.errors.length > 0 && (
                                <div className="bg-red-900/20 border border-red-800 rounded-lg p-4">
                                    <div className="flex items-center gap-2 mb-3">
                                        <AlertCircle className="text-red-400" size={20} />
                                        <p className="text-sm font-medium text-red-400">
                                            {validationResults.errors.length} errors found
                                        </p>
                                    </div>
                                    <div className="space-y-2 max-h-64 overflow-y-auto">
                                        {validationResults.errors.map((error, index) => (
                                            <div key={index} className="bg-slate-900 rounded-lg p-3">
                                                <p className="text-xs text-red-400 font-medium mb-1">
                                                    Row {error.row} - Field: {error.field}
                                                </p>
                                                <p className="text-xs text-slate-400">{error.message}</p>
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {/* Action after validation */}
                            {validateOnly && validationResults.errors.length === 0 && validationResults.success > 0 && (
                                <div className="bg-slate-800 border border-slate-700 rounded-lg p-4">
                                    <p className="text-sm text-slate-300 mb-3">
                                        All records are valid. Ready to import?
                                    </p>
                                    <button
                                        onClick={() => {
                                            setValidateOnly(false);
                                            handleImport();
                                        }}
                                        className="px-4 py-2 bg-teal-600 hover:bg-teal-500 text-white text-sm font-medium rounded-lg transition-colors"
                                    >
                                        Proceed with Import
                                    </button>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </div>

            {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
        </div>
    );
};

export default ImportExportPage;
