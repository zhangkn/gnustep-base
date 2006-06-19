/* Implementation for NSURLCache for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <frm@gnu.org>
   Date: 2006
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#include "GSURLPrivate.h"

// FIXME ... locking and disk storage needed
typedef struct {
  unsigned		diskCapacity;
  unsigned		memoryCapacity;
  unsigned		diskUsage;
  unsigned		memoryUsage;
  NSString		*path;
  NSMutableDictionary	*memory;
} Internal;
 
typedef struct {
  @defs(NSURLCache)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSURLCacheInternal))
#define	inst	((Internal*)(((priv*)o)->_NSURLCacheInternal))


static NSURLCache	*shared = nil;

@implementation	NSURLCache

+ (id) allocWithZone: (NSZone*)z
{
  NSURLCache	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLCacheInternal = NSZoneMalloc(z, sizeof(Internal));
      memset(o->_NSURLCacheInternal, '\0', sizeof(Internal));
    }
  return o;
}

+ (void) setSharedURLCache: (NSURLCache *)cache
{
  [gnustep_global_lock lock];
  ASSIGN(shared, cache);
  [gnustep_global_lock unlock];
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->memory);
      RELEASE(this->path);
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

+ (NSURLCache *) sharedURLCache
{
  NSURLCache	*c;

  [gnustep_global_lock lock];
  if (shared == nil)
    {
      NSString	*path = nil;

// FIXME user-library-path/Caches/current-app-name

      shared = [[self alloc] initWithMemoryCapacity: 4 * 1024 * 1024
				       diskCapacity: 20 * 1024 * 1024
					   diskPath: path];
      
    }
  c = RETAIN(shared);
  [gnustep_global_lock unlock];
  return AUTORELEASE(c);
}

- (NSCachedURLResponse *) cachedResponseForRequest: (NSURLRequest *)request
{
  // FIXME ... handle disk cache
  return [this->memory objectForKey: request];
}

- (unsigned) currentDiskUsage
{
  return this->diskUsage;
}

- (unsigned) currentMemoryUsage
{
  return this->memoryUsage;
}

- (unsigned) diskCapacity
{
  return this->diskCapacity;
}

- (id) initWithMemoryCapacity: (unsigned)memoryCapacity
		 diskCapacity: (unsigned)diskCapacity
		     diskPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      this->diskUsage = 0;
      this->diskCapacity = diskCapacity;
      this->memoryUsage = 0;
      this->memoryCapacity = memoryCapacity;
      this->path = [path copy];
      this->memory = [NSMutableDictionary new];
    }
  return self;
}

- (unsigned) memoryCapacity
{
  return this->memoryCapacity;
}

- (void) removeAllCachedResponses
{
  // FIXME ... disk storage
  [this->memory removeAllObjects];
  this->diskUsage = 0;
  this->memoryUsage = 0;
}

- (void) removeCachedResponseForRequest: (NSURLRequest *)request
{
  NSCachedURLResponse	*item = [self cachedResponseForRequest: request];

  if (item != nil)
    {
      // FIXME ... disk storage
      this->memoryUsage -= [[item data] length];
      [this->memory removeObjectForKey: request];
    }
}

- (void) setDiskCapacity: (unsigned)diskCapacity
{
  // FIXME
}

- (void) setMemoryCapacity: (unsigned)memoryCapacity
{
  // FIXME
}

- (void) storeCachedResponse: (NSCachedURLResponse *)cachedResponse
		  forRequest: (NSURLRequest *)request
{
  switch ([cachedResponse storagePolicy])
    {
      case NSURLCacheStorageAllowed:
// FIXME ... maybe on disk?

      case NSURLCacheStorageAllowedInMemoryOnly:
        {
	  unsigned		size = [[cachedResponse data] length];

	  if (size < this->memoryCapacity)
	    {
	      NSCachedURLResponse	*old;

	      old = [this->memory objectForKey: request];
	      if (old != nil)
		{
		  this->memoryUsage -= [[old data] length];
		  [this->memory removeObjectForKey: request];
		}
	      while (this->memoryUsage + size > this->memoryCapacity)
	        {
// FIXME ... should delete least recently used.
		  [self removeCachedResponseForRequest:
		    [[this->memory allKeys] lastObject]];
		}
	      [this->memory setObject: cachedResponse forKey: request];
	      this->memoryUsage += size;
	    }
	  }
        break;

      case NSURLCacheStorageNotAllowed:
        break;

      default:
        [NSException raise: NSInternalInconsistencyException
		    format: @"storing cached response with bad policy (%d)",
		    [cachedResponse storagePolicy]];
    }
}

@end
