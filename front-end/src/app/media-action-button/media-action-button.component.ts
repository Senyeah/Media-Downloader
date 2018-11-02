import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'app-media-action-button',
  templateUrl: './media-action-button.component.html',
  styleUrls: ['./media-action-button.component.scss']
})
export class MediaActionButtonComponent implements OnInit {

  @Input() title: string;

  constructor() { }

  ngOnInit() {
  }

}
