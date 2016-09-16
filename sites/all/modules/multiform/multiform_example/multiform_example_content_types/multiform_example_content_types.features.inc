<?php
/**
 * @file
 * multiform_example_content_types.features.inc
 */

/**
 * Implements hook_node_info().
 */
function multiform_example_content_types_node_info() {
  $items = array(
    'multiform_base' => array(
      'name' => t('multiform_base'),
      'base' => 'node_content',
      'description' => '',
      'has_title' => '1',
      'title_label' => t('Title'),
      'help' => '',
    ),
    'multiform_dependent' => array(
      'name' => t('multiform_dependent'),
      'base' => 'node_content',
      'description' => '',
      'has_title' => '1',
      'title_label' => t('Title'),
      'help' => '',
    ),
  );
  return $items;
}
