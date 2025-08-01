---
title: Exercises for DevOps practitioners and Platform engineers
description: Hands-on exercises for DevOps, DevSecOps, SRE, and Platform Engineering
permalink: index.html
layout: home
---

# Overview

The following exercises are designed to provide you with a hands-on learning experience where you'll explore common tasks DevOps practitioners and Platform engineers perform when building solutions on Azure.

> **Note**: To complete the exercises, you'll need an Azure subscription in which you have sufficient permissions and quota to provision the necessary Azure resources. If you don't already have one, you can sign up for an [Azure account](https://azure.microsoft.com/free).

Some exercises may have additional, or different, requirements. Those will contain a **Before you start** section specific to that exercise.

## Topic levels

{% assign exercises = site.pages | where_exp:"page", "page.url contains '/Instructions'" %}
{% assign grouped_exercises = exercises | group_by: "lab.topic" %}
{% assign topic_order = "Basic,Intermediate,Advanced,Expert" | split: "," %}
{% assign sorted_groups = "" | split: "" %}
{% for topic in topic_order %}
  {% assign matching_group = grouped_exercises | where: "name", topic | first %}
  {% if matching_group %}
    {% assign sorted_groups = sorted_groups | push: matching_group %}
  {% endif %}
{% endfor %}

<ul>
{% for group in sorted_groups %}
<li><a href="#{{ group.name | slugify }}">{{ group.name }}</a></li>
{% endfor %}
</ul>

{% for group in sorted_groups %}

## <a id="{{ group.name | slugify }}"></a>{{ group.name }}

{% for activity in group.items %}
[{{ activity.lab.title }}]({{ site.github.url }}{{ activity.url }}) <br/> {{ activity.lab.description }}

---

{% endfor %}
<a href="#overview">Return to top</a>
{% endfor %}
