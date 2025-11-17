import { useState, useCallback } from 'react';

interface UseClipboardResult {
  isCopied: boolean;
  copy: (text: string) => Promise<void>;
}

export const useClipboard = (resetDelay = 2000): UseClipboardResult => {
  const [isCopied, setIsCopied] = useState(false);

  const copy = useCallback(
    async (text: string) => {
      try {
        await navigator.clipboard.writeText(text);
        setIsCopied(true);
        setTimeout(() => setIsCopied(false), resetDelay);
      } catch (err) {
        console.error('Failed to copy to clipboard:', err);
      }
    },
    [resetDelay]
  );

  return { isCopied, copy };
};
