import { createContext, useContext } from 'react';
import type { UserInfo } from '../mockData';
import { hasPermission } from './permissions';

export const PermissionUserContext = createContext<UserInfo | null>(null);
export function usePermission(code: string): boolean {
  return hasPermission(useContext(PermissionUserContext), code);
}

export function usePermissionCheck(): (code: string) => boolean {
  const user = useContext(PermissionUserContext);
  return code => hasPermission(user, code);
}
