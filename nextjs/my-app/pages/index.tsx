import Image from "next/image";
import { Geist, Geist_Mono } from "next/font/google";
import { useState, useEffect, useRef } from "react";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

interface LogEntry {
  id: string;
  action: string;
  timestamp?: string;
}

export default function Home() {
  const [allLogs, setAllLogs] = useState<LogEntry[]>([]);
  const [displayedLogs, setDisplayedLogs] = useState<LogEntry[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Add ref variable
  const logsContainerRef = useRef<HTMLDivElement>(null);

  // Fetch all logs once
  useEffect(() => {
    const fetchLogs = async () => {
      try {
        const response = await fetch('/api/logs');
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data: LogEntry[] = await response.json();
        
        // Only update if we have new logs
        if (data.length !== allLogs.length) {
          setAllLogs(data);
          // Update displayed logs to show all new logs immediately
          setDisplayedLogs(data);
          setCurrentIndex(data.length);
        }
        
        setError(null);
      } catch (err) {
        console.error('Failed to fetch logs:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch logs');
      } finally {
        setIsLoading(false);
      }
    };

    // Fetch immediately
    fetchLogs();
    
    // Then fetch every second
    const interval = setInterval(fetchLogs, 1000);
    
    return () => clearInterval(interval);
  }, [allLogs.length]); // Add dependency to avoid infinite loops

  // Add auto-scroll effect
  useEffect(() => {
    if (logsContainerRef.current) {
      logsContainerRef.current.scrollTop = logsContainerRef.current.scrollHeight;
    }
  }, [displayedLogs]);

  const renderActionWithIcons = (action: string) => {
    let processedAction = action;
    
    // Handle both wallets in the correct order they appear in text
    if (action.toLowerCase().includes('wallet 3') && action.toLowerCase().includes('wallet 1')) {
      // Both wallets mentioned - replace in order of appearance
      const wallet3First = action.toLowerCase().indexOf('wallet 3') < action.toLowerCase().indexOf('wallet 1');
      
      if (wallet3First) {
        processedAction = processedAction.replace(/wallet\s*3/gi, '🔴').replace(/wallet\s*1/gi, '🟢');
      } else {
        processedAction = processedAction.replace(/wallet\s*1/gi, '🟢').replace(/wallet\s*3/gi, '🔴');
      }
      
      return <span>{processedAction}</span>;
    }
    
    // Single wallet mentions
    if (action.toLowerCase().includes('wallet 1')) {
      processedAction = processedAction.replace(/wallet\s*1/gi, '🟢');
    }
    
    if (action.toLowerCase().includes('wallet 3')) {
      processedAction = processedAction.replace(/wallet\s*3/gi, '🔴');
    }

    return <span>{processedAction}</span>;
  };

  return (
    <div
      className={`${geistSans.className} ${geistMono.className} grid grid-rows-[20px_1fr_20px] items-center justify-items-center min-h-screen p-8 pb-20 gap-16 sm:p-20 font-[family-name:var(--font-geist-sans)]`}
    >
      <main className="flex flex-col gap-[32px] row-start-2 items-center sm:items-start max-w-6xl w-full">        
        <div className="w-full">
          <h2 className="text-xl font-semibold mb-4 font-[family-name:var(--font-geist-mono)]">
            CTF Game Logs
            {isLoading && <span className="ml-2 text-sm text-gray-500">Loading...</span>}
          </h2>
          
          {error && (
            <div className="mb-4 p-3 bg-red-100 dark:bg-red-900/20 border border-red-300 dark:border-red-700 rounded text-red-700 dark:text-red-300">
              Error: {error}
            </div>
          )}
          
          <div 
            ref={logsContainerRef}
            className="bg-gray-50 dark:bg-gray-900 rounded-lg p-4 overflow-y-auto"
            style={{ height: 'calc(100vh - 300px)' }}
          >
            {displayedLogs.length === 0 ? (
              <p className="text-gray-500 text-center py-4">
                {isLoading ? 'Loading logs...' : 'Waiting for game to start...'}
              </p>
            ) : (
              <div className="space-y-2">
                {displayedLogs.map((log, index) => (
                  <div 
                    key={log.id} 
                    className="grid grid-cols-[80px_1fr] gap-4 bg-white dark:bg-gray-800 p-3 rounded border items-center"
                  >
                    {/* Block Number Column */}
                    <div className="text-right">
                      <span className="font-[family-name:var(--font-geist-mono)] text-xs text-gray-600 dark:text-gray-400">
                        Block
                      </span>
                      <div className="font-[family-name:var(--font-geist-mono)] text-lg font-bold text-blue-600 dark:text-blue-400">
                        {log.id}
                      </div>
                    </div>
                    
                    {/* Action Column */}
                    <div className="font-[family-name:var(--font-geist-mono)] text-sm">
                      {renderActionWithIcons(log.action)}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
          
          
          {/* Legend */}
          <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <h3 className="text-sm font-semibold mb-2">Legend:</h3>
            <div className="flex gap-4 text-xs">
              <div className="flex items-center">
                <div className="w-4 h-4 rounded-full bg-green-500 mr-2"></div>
                <span>Wallet 1</span>
              </div>
              <div className="flex items-center">
                <div className="w-4 h-4 rounded-full bg-red-500 mr-2"></div>
                <span>Wallet 3</span>
              </div>
            </div>
          </div>
        </div>
      </main>
      
    </div>
  );
}
