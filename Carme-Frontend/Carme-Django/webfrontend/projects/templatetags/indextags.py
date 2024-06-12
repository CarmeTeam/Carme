from django import template

register = template.Library()

@register.filter
def index(indexable, i):
    return indexable[i]

@register.simple_tag
def update_variable(value):
    """Allows to update existing variable in template"""
    return value
