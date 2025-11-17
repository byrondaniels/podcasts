export interface ValidationResult {
  isValid: boolean;
  error: string | null;
}

export const validateUrl = (url: string): ValidationResult => {
  if (!url.trim()) {
    return {
      isValid: false,
      error: 'RSS feed URL is required',
    };
  }

  try {
    const urlObj = new URL(url);
    if (!['http:', 'https:'].includes(urlObj.protocol)) {
      return {
        isValid: false,
        error: 'URL must start with http:// or https://',
      };
    }
  } catch {
    return {
      isValid: false,
      error: 'Please enter a valid URL',
    };
  }

  return {
    isValid: true,
    error: null,
  };
};
