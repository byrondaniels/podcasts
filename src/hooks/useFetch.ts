import { useState, useEffect, useCallback } from 'react';

interface UseFetchOptions<T> {
  fetchFn: () => Promise<T>;
  dependencies?: unknown[];
  immediate?: boolean;
}

interface UseFetchResult<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => Promise<void>;
}

export const useFetch = <T>({
  fetchFn,
  dependencies = [],
  immediate = true,
}: UseFetchOptions<T>): UseFetchResult<T> => {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const execute = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const result = await fetchFn();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setIsLoading(false);
    }
  }, [fetchFn]);

  useEffect(() => {
    if (immediate) {
      execute();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...dependencies, execute, immediate]);

  return { data, isLoading, error, refetch: execute };
};
