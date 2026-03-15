import os
from pathlib import Path
from django.apps import apps

class LuaScriptLoader:
    """Utility to load and cache Lua scripts from any Django app"""
    
    _cache = {}
    
    @classmethod
    def load(cls, app_name: str, script_name: str) -> str:
        """
        Load a Lua script from a specific Django app's 'lua' directory.
        """
        # Create a unique cache key to prevent name collisions between apps
        cache_key = f"{app_name}:{script_name}"
        
        if cache_key in cls._cache:
            return cls._cache[cache_key]
        
        # Dynamically get the absolute path of the requested Django app
        try:
            app_path = Path(apps.get_app_config(app_name).path)
        except LookupError:
            raise ValueError(f"Django app '{app_name}' not found")
            
        # Point to the 'lua' directory inside that app
        script_path = app_path / 'lua' / f"{script_name}.lua"
        
        if not script_path.exists():
            raise FileNotFoundError(f"Lua script not found: {script_path}")
        
        with open(script_path, 'r', encoding='utf-8') as f:
            script_content = f.read()
        
        cls._cache[cache_key] = script_content
        return script_content
    
    @classmethod
    def clear_cache(cls):
        """Clear the script cache (useful for development)"""
        cls._cache.clear()