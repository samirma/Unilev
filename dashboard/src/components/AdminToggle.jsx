"use client";

import { useAdmin } from "../contexts/AdminContext";

export function AdminToggle() {
    const { isAdmin, toggleAdminMode } = useAdmin();

    return (
        <div className="flex items-center gap-2 mr-2">
            <span className="text-xs text-gray-400 font-bold uppercase tracking-wider">
                Admin
            </span>
            <button
                onClick={toggleAdminMode}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                    isAdmin ? "bg-cyan-500" : "bg-gray-600"
                }`}
            >
                <span
                    className={`inline-block h-3 w-3 transform rounded-full bg-white transition-transform ${
                        isAdmin ? "translate-x-5" : "translate-x-1"
                    }`}
                />
            </button>
        </div>
    );
}
