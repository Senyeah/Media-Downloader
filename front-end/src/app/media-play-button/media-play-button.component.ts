import { Component, Input, OnInit } from '@angular/core';

@Component({
  selector: 'app-media-play-button',
  templateUrl: './media-play-button.component.html',
  styleUrls: ['./media-play-button.component.scss']
})
export class MediaPlayButtonComponent implements OnInit {

  @Input() title: string;

  constructor() { }

  ngOnInit() {
  }

}
